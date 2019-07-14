use ggez::nalgebra as na;

pub struct Camera {
    forward: na::Vector3<f32>,
    pos: na::Vector3<f32>,
    up: na::Vector3<f32>,
}

impl Camera {
    pub fn new(pos: na::Vector3<f32>, forward: na::Vector3<f32>, up: na::Vector3<f32>) -> Self {
        Camera {
            pos: pos,
            forward: forward,
            up: up,
        }
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
        self.forward.cross(&self.up)
    }

    pub fn translate(&mut self, translation: na::Vector3<f32>) {
        self.pos += translation;
    }
}
