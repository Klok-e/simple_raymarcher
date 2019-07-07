#version 150 core

in vec2 v_Uv;
out vec4 Target0;

uniform Locals{
    float u_Time;
};

void main() {
    vec3 res=max(vec3(0.3,sin(v_Uv.x*50.+u_Time*10.),0.6),vec3(0.3,sin(v_Uv.y*50.),0.6));

    Target0=vec4(res,1.0);
}
