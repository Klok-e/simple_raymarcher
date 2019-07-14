#version 150 core

in vec3 a_Pos;
in vec2 a_Uv;
out vec2 v_Uv;

void main() {
    gl_Position = vec4(a_Pos,1);
    v_Uv=a_Uv;
}