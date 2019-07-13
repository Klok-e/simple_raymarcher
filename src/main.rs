mod pipeline_def;
use pipeline_def::{pipe, Locals, Vertex};

use arr_macro::arr;
use gfx;
use gfx::traits::FactoryExt;
use gfx_device_gl;
use ggez::conf;
use ggez::event::{self, EventHandler};
use ggez::graphics;
use ggez::nalgebra as na;
use ggez::timer;
use ggez::{Context, ContextBuilder, GameResult};
use num;

static FRAGMENT_GLSL: &[u8] = include_bytes!("./shader_fragment.glsl");
static VERTEX_GLSL: &[u8] = include_bytes!("./shader_vertex.glsl");

const IDENTITY_MAT: [[f32; 4]; 4] = [
    [1., 0., 0., 0.],
    [0., 1., 0., 0.],
    [0., 0., 1., 0.],
    [0., 0., 0., 1.],
];

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
            width: 800.0,
            height: 600.0,
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
    locals: Locals,
    pso: gfx::pso::PipelineState<gfx_device_gl::Resources, pipe::Meta>,
    data: pipe::Data<gfx_device_gl::Resources>,
    slice: gfx::Slice<gfx_device_gl::Resources>,
}

impl MyGame {
    fn new(ctx: &mut Context) -> GameResult<Self> {
        let mut cached_fps_text = arr![graphics::Text::default();99];
        for (i, item) in cached_fps_text.iter_mut().enumerate() {
            let font = graphics::Font::default();
            let text = graphics::Text::new((i.to_string(), font, 24.0));
            *item = text;
        }

        let (factory, _device, _encoder, _depthview, colour_view) = graphics::gfx_objects(ctx);

        let pso = factory.create_pipeline_simple(VERTEX_GLSL, FRAGMENT_GLSL, pipe::new())?;
        let quad = &[
            Vertex {
                pos: [-1., -1.],
                uv: [0., 0.],
            },
            Vertex {
                pos: [1., -1.],
                uv: [1., 0.],
            },
            Vertex {
                pos: [1., 1.],
                uv: [1., 1.],
            },
            Vertex {
                pos: [-1., 1.],
                uv: [0., 1.],
            },
        ];
        let indices: &[u16] = &[0, 1, 2, 0, 2, 3];
        let (vertex_buffer, slice) = factory.create_vertex_buffer_with_slice(quad, indices);
        let data = pipe::Data {
            locals: factory.create_constant_buffer(1),
            out: gfx::memory::Typed::new(colour_view),
            vbuf: vertex_buffer,
        };

        Ok(MyGame {
            fps_text_cached: cached_fps_text,
            locals: Locals {
                time: [0., 0.],
                image_size: get_screen_size(ctx),
                camera_to_world: IDENTITY_MAT,
            },
            pso: pso,
            data: data,
            slice: slice,
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
    fn update(&mut self, _ctx: &mut Context) -> GameResult<()> {
        Ok(())
    }

    fn resize_event(&mut self, ctx: &mut Context, width: f32, height: f32) {
        self.update_render_target(ctx, width, height).unwrap();
        self.locals.image_size = get_screen_size(ctx);
    }

    fn draw(&mut self, ctx: &mut Context) -> GameResult<()> {
        graphics::clear(ctx, [0., 0., 0., 1.].into());

        let time = ggez::timer::time_since_start(ctx).as_millis() as f32 / 1000.;

        self.locals.time = [time, 0.];
        self.locals.camera_to_world = IDENTITY_MAT;

        let encoder = graphics::encoder(ctx);

        encoder.update_constant_buffer(&self.data.locals, &self.locals);
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
