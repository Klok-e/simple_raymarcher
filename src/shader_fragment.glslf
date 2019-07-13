#version 150 core

const float PI = 3.14159265359;
const int MARCH_STEPS = 10;
const float MARCH_HIT_THRESHOLD = 0.0001;

in vec2 v_Uv;
out vec4 Target0;

uniform Locals
{
    float u_Time;
    vec2 u_ImageSize;
    mat4 u_CameraToWorld;
};

float sphereSDF(vec3 point, vec3 sphereCentre, float radius)
{
    vec3 pointToCentre = point-sphereCentre;
    return dot(pointToCentre, pointToCentre) - radius * radius;
}

float sceneSDF(vec3 point)
{
    return sphereSDF(point, vec3(0., 0., -2), 1.3);
}

vec3 get_ray(vec2 uv, float fov)
{
    vec2 norm_uv = uv*2. - 1.;
    float aspect_ratio = u_ImageSize.x / u_ImageSize.y;
    norm_uv.x *= aspect_ratio;
    norm_uv *= tan(fov / 2);

    vec4 ray_camera = vec4(norm_uv, -1, 0);
    vec4 origin_camera = vec4(0, 0, 0, 1);

    vec4 ray_world = u_CameraToWorld * ray_camera;
    vec4 origin_world = u_CameraToWorld * origin_camera;

    vec3 ray_dir = (ray_world - origin_world).xyz;
    return normalize(ray_dir);
}

void main() 
{
    //vec2 uv_scaled = vec2(v_Uv.x * u_ImageSize.x / u_ImageSize.y, v_Uv.y);
    //vec3 hit_color = max(vec3(0.3,sin(uv_scaled.x*50.+u_Time*10.),0.6),vec3(0.3,sin(uv_scaled.y*50.),0.6));

    vec3 origin_world = (u_CameraToWorld * vec4(0, 0, 0, 1)).xyz;
    vec3 ray = get_ray(v_Uv, PI/2.);
    vec3 hit_color = vec3(0);

    float min_distance = sceneSDF(origin_world);
    float distance_marched = min_distance;
    for(int i = 0; i < MARCH_STEPS; i++) 
    {
        float dist = sceneSDF(ray * distance_marched);
        min_distance = min(min_distance, dist);

        if(dist < MARCH_HIT_THRESHOLD)
            break;
        
        distance_marched += dist;
    }

    if(min_distance < MARCH_HIT_THRESHOLD)
        hit_color = vec3(0.7, 0.4, 0.3);
    
    Target0=vec4(hit_color,1.0);
}
