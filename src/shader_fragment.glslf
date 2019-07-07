#version 150 core

in vec2 v_Uv;
out vec4 Target0;

uniform Locals{
    float u_Time;
};

void main() {
    vec3 res=vec3(sin(v_Uv+u_Time)/2.+0.5,cos(v_Uv.x*v_Uv.y+u_Time)/2.+0.5);
    Target0=vec4(res,1.0);
}
