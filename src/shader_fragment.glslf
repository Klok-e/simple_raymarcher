#version 150 core

in 
out vec4 Target0;

layout (std140) uniform Dim {
    float u_Rate;
};

void main() {
    Target0 = texture(t_Texture, v_Uv) * v_Color * u_Rate;
}
