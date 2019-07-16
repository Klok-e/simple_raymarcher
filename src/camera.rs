use ggez::nalgebra as na;

#[derive(Debug)]
pub struct Camera {
    pos: na::Vector3<f32>,
    forward: na::Unit<na::Vector3<f32>>,
    up: na::Unit<na::Vector3<f32>>,
    right: na::Unit<na::Vector3<f32>>,
}

impl Default for Camera {
    fn default() -> Self {
        Camera {
            pos: [0., 0., 0.].into(),
            forward: na::Unit::new_normalize([0., 0., -1.].into()),
            up: na::Unit::new_normalize([0., 1., 0.].into()),
            right: na::Unit::new_normalize([1., 0., 0.].into()),
        }
    }
}

impl Camera {
    pub fn _new(
        pos: na::Vector3<f32>,
        forward: na::Unit<na::Vector3<f32>>,
        up: na::Unit<na::Vector3<f32>>,
    ) -> Self {
        let mut cam = Camera {
            pos: pos,
            forward: forward,
            up: up,
            right: Camera::default().right,
        };
        cam.fix_up_right();
        cam
    }
    pub fn position(&self) -> na::Vector3<f32> {
        self.pos
    }

    pub fn forward(&self) -> na::Unit<na::Vector3<f32>> {
        self.forward
    }

    pub fn up(&self) -> na::Unit<na::Vector3<f32>> {
        self.up
    }

    pub fn right(&self) -> na::Unit<na::Vector3<f32>> {
        self.right
    }

    pub fn translate(&mut self, translation: na::Vector3<f32>) {
        self.pos += translation;
    }

    pub fn rotate_by(&mut self, rot_x: f32, rot_y: f32) {
        let cam_default = Camera::default();
        let rot_around_up = na::Rotation3::from_axis_angle(&cam_default.up, rot_x);
        let rot_around_right = na::Rotation3::from_axis_angle(&self.right, rot_y);

        self.forward = rot_around_right * rot_around_up * self.forward;

        self.fix_up_right();
    }

    fn fix_up_right(&mut self) {
        let cam_def = Camera::default();
        self.right = na::Unit::new_normalize(self.forward.cross(cam_def.up.as_ref()));
        self.up = na::Unit::new_normalize(self.right.cross(&self.forward));
    }
}
