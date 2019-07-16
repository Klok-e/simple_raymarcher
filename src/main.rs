mod camera;
mod pipeline_def;
use camera::Camera;
use pipeline_def::{pipe, CameraConsts, Vertex};

use arr_macro::arr;
use gfx;
use gfx::traits::FactoryExt;
use gfx_device_gl;
use ggez::conf;
use ggez::event::{self, EventHandler};
use ggez::graphics;
use ggez::input::keyboard;
use ggez::input::mouse;
use ggez::nalgebra as na;
use ggez::timer;
use ggez::{Context, ContextBuilder, GameResult};
use num;

static FRAGMENT_GLSL: &[u8] = include_bytes!("./shader_fragment.glsl");

static VERTEX_GLSL: &[u8] = include_bytes!("./shader_vertex.glsl");

fn main() -> GameResult<()> {
    // Make a Context and an EventLoop.
    let (mut ctx, mut event_loop) = ContextBuilder::new("Raymarcher", "Dmitry")
        .window_setup(conf::WindowSetup {
            title: "Fractal Raymarcher".to_owned(),
            samples: conf::NumSamples::Zero,
            vsync: true,
            transparent: false,
            icon: "".to_owned(),
            srgb: true,
        })
        .window_mode(conf::WindowMode {
            width: 1200.0,
            height: 800.0,
            maximized: false,
            fullscreen_type: conf::FullscreenType::Windowed,
            borderless: false,
            min_width: 0.0,
            max_width: 0.0,
            min_height: 0.0,
            max_height: 0.0,
            hidpi: false,
            resizable: true,
        })
        .build()?;
    mouse::set_cursor_grabbed(&mut ctx, true)?;

    // Create an instance of your event handler.
    // Usually, you should provide it with the Context object to
    // use when setting your game up.
    let mut my_game = MyGame::new(&mut ctx)?;

    // Run!
    match event::run(&mut ctx, &mut event_loop, &mut my_game) {
        Ok(_) => println!("Exited cleanly"),
        Err(e) => println!("Error occured: {}", e),
    }
    Ok(())
}

struct MyGame {
    fps_text_cached: [graphics::Text; 99],
    pso: gfx::pso::PipelineState<gfx_device_gl::Resources, pipe::Meta>,
    data: pipe::Data<gfx_device_gl::Resources>,
    slice: gfx::Slice<gfx_device_gl::Resources>,

    camera_consts: CameraConsts,
    time: f32,

    camera: Camera,
}

impl MyGame {
    fn new(ctx: &mut Context) -> GameResult<Self> {
        let mut cached_fps_text = arr![graphics::Text::default();99];
        for (i, item) in cached_fps_text.iter_mut().enumerate() {
            let font = graphics::Font::default();
            let text = graphics::Text::new((i.to_string(), font, 24.0));
            *item = text;
        }

        let screen_size = get_screen_size(ctx);

        let (factory, _device, _encoder, _depthview, colour_view) = graphics::gfx_objects(ctx);

        let pso = match factory.create_pipeline_simple(VERTEX_GLSL, FRAGMENT_GLSL, pipe::new()) {
            Ok(v) => v,
            Err(msg) => {
                dbg!(msg);
                panic!("AAAAAAAAAAAAAAAA");
            }
        };
        let quad = &[
            Vertex {
                pos: [-1., -1., 0.],
                uv: [0., 0.],
            },
            Vertex {
                pos: [1., -1., 0.],
                uv: [1., 0.],
            },
            Vertex {
                pos: [1., 1., 0.],
                uv: [1., 1.],
            },
            Vertex {
                pos: [-1., 1., 0.],
                uv: [0., 1.],
            },
        ];
        let indices: &[u16] = &[0, 1, 2, 0, 2, 3];
        let (vertex_buffer, slice) = factory.create_vertex_buffer_with_slice(quad, indices);
        let default_camera = Camera::default();

        let camera_consts = CameraConsts {
            camera_pos: vec3_to_vec4_pad_zeros(&default_camera.position()).into(),
            camera_forward: vec3_to_vec4_pad_zeros(default_camera.forward().as_ref()).into(),
            camera_right: vec3_to_vec4_pad_zeros(default_camera.right().as_ref()).into(),
            camera_up: vec3_to_vec4_pad_zeros(default_camera.up().as_ref()).into(),
        };

        let data = pipe::Data {
            camera_consts: factory.create_constant_buffer(1),
            out: gfx::memory::Typed::new(colour_view),
            vbuf: vertex_buffer,
            time: 0.,
            image_size: screen_size,
        };

        Ok(MyGame {
            fps_text_cached: cached_fps_text,
            camera_consts: camera_consts,
            pso: pso,
            data: data,
            slice: slice,
            camera: default_camera,
            time: 0.,
        })
    }

    fn update_render_target(
        &mut self,
        ctx: &mut Context,
        width: f32,
        height: f32,
    ) -> GameResult<()> {
        graphics::set_screen_coordinates(
            ctx,
            graphics::Rect {
                x: 0.,
                y: 0.,
                w: width,
                h: height,
            },
        )?;
        let colour_view = graphics::screen_render_target(ctx);
        self.data.out = gfx::memory::Typed::new(colour_view);
        Ok(())
    }
}

impl EventHandler for MyGame {
    fn update(&mut self, ctx: &mut Context) -> GameResult<()> {
        const SPEED: f32 = 0.05;
        const ROT_SPEED: f32 = 0.002;
        const ARROWS_ROT_SPEED: f32 = 5.;

        let mut translation = na::Vector3::new(0., 0., 0.);
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::A) {
            translation += na::Vector3::new(-1., 0., 0.);
        }
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::D) {
            translation += na::Vector3::new(1., 0., 0.);
        }
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::W) {
            translation += na::Vector3::new(0., 0., 1.);
        }
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::S) {
            translation += na::Vector3::new(0., 0., -1.);
        }
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::PageUp) {
            translation += na::Vector3::new(0., 1., 0.);
        }
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::PageDown) {
            translation += na::Vector3::new(0., -1., 0.);
        }
        if translation.magnitude_squared() >= 1. {
            translation.normalize_mut();
        }
        self.camera
            .translate(self.camera.forward().as_ref() * translation.z * SPEED);
        self.camera
            .translate(self.camera.up().as_ref() * translation.y * SPEED);
        self.camera
            .translate(self.camera.right().as_ref() * translation.x * SPEED);

        let mut rotation_y = 0.;
        let mut rotation_x = 0.;
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::Up) {
            rotation_y += ARROWS_ROT_SPEED;
        }
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::Down) {
            rotation_y += -ARROWS_ROT_SPEED;
        }
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::Left) {
            rotation_x += ARROWS_ROT_SPEED;
        }
        if keyboard::is_key_pressed(ctx, keyboard::KeyCode::Right) {
            rotation_x += -ARROWS_ROT_SPEED;
        }

        let pos = mouse::position(ctx);
        let pos = na::Vector2::from([pos.x, pos.y]);
        let moved = pos - na::Vector2::from(get_screen_size(ctx)) / 2.;

        rotation_y -= moved.y;
        rotation_x -= moved.x;
        self.camera
            .rotate_by(rotation_x * ROT_SPEED, rotation_y * ROT_SPEED);
        Ok(())
    }

    fn resize_event(&mut self, ctx: &mut Context, width: f32, height: f32) {
        self.update_render_target(ctx, width, height).unwrap();
        self.data.image_size = get_screen_size(ctx);
    }

    fn draw(&mut self, ctx: &mut Context) -> GameResult<()> {
        let screen_size = get_screen_size(ctx);
        mouse::set_position(ctx, [screen_size[0] / 2., screen_size[1] / 2.])?;

        graphics::clear(ctx, [0., 0., 0., 1.].into());

        //dbg!(&self.camera);

        let time = ggez::timer::time_since_start(ctx).as_millis() as f32 / 1000.;

        self.time = time;
        self.camera_consts.camera_pos = vec3_to_vec4_pad_zeros(&self.camera.position()).into();
        self.camera_consts.camera_forward =
            vec3_to_vec4_pad_zeros(self.camera.forward().as_ref()).into();
        self.camera_consts.camera_up = vec3_to_vec4_pad_zeros(self.camera.up().as_ref()).into();
        self.camera_consts.camera_right =
            vec3_to_vec4_pad_zeros(self.camera.right().as_ref()).into();

        let encoder = graphics::encoder(ctx);

        self.data.time = self.time;

        encoder.update_constant_buffer(&self.data.camera_consts, &self.camera_consts);
        encoder.draw(&self.slice, &self.pso, &self.data);

        // draw fps
        graphics::draw(
            ctx,
            &self.fps_text_cached[num::clamp(timer::fps(ctx).round() as usize, 0, 99)],
            graphics::DrawParam::new()
                .color((1., 1., 1., 1.).into())
                .dest(na::Point2::new(0., 0.)),
        )?;

        graphics::present(ctx)?;
        Ok(())
    }
}

fn get_screen_size(ctx: &Context) -> [f32; 2] {
    let screen_rect = graphics::screen_coordinates(ctx);
    [screen_rect.w, screen_rect.h]
}

fn get_aspect_ratio(ctx: &Context) -> f32 {
    let screens = get_screen_size(ctx);
    screens[0] / screens[1]
}

fn vec3_to_vec4_pad_zeros(vec: &na::Vector3<f32>) -> na::Vector4<f32> {
    [vec.x, vec.y, vec.z, 0.].into()
}
