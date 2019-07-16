use ggez::nalgebra as na;

pub struct Camera {
    pos: na::Vector3<f32>,
    forward: na::Vector3<f32>,
    up: na::Vector3<f32>,
    right: na::Vector3<f32>,
}

impl Camera {
    pub fn new(pos: na::Vector3<f32>, forward: na::Vector3<f32>, up: na::Vector3<f32>) -> Self {
        let mut cam = Camera {
            pos: pos,
            forward: forward,
            up: up,
            right: forward.cross(&up),
        };
        cam.fix_up_right();
        cam
    }
    pub fn position(&self) -> na::Vector3<f32> {
        self.pos
    }

    pub fn forward(&self) -> na::Vector3<f32> {
        self.forward
    }

    pub fn up(&self) -> na::Vector3<f32> {
        self.up
    }

    pub fn right(&self) -> na::Vector3<f32> {
        self.right
    }

    pub fn translate(&mut self, translation: na::Vector3<f32>) {
        self.pos += translation;
    }

    pub fn rotate_by(&mut self, rot_x: f32, rot_y: f32) {
        let rot = na::Rotation3::from_euler_angles(rot_y, rot_x, 0.);
        self.forward = rot * self.forward;
        self.up = rot * self.up;
        self.fix_up_right();
    }

    fn fix_up_right(&mut self) {
        self.right = self.forward.cross(&self.up);
        self.up = self.right.cross(&self.forward);
    }
}
