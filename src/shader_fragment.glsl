#version 150 core

const float PI = 3.14159265359;
const int MARCH_STEPS = 255;
const float EPSILON = 0.0001;
const float MAX_DISTANCE = 10000.;

in vec2 v_Uv;
out vec4 Target0;

uniform CameraConsts
{
    vec3 u_CamPos;
    vec3 u_CamForward;
    vec3 u_CamUp;
    vec3 u_CamRight;
};

uniform float u_Time;
uniform vec2 u_ImageSize;

float intersectSDF(float distA, float distB) 
{
    return max(distA, distB);
}

float unionSDF(float distA, float distB) 
{
    return min(distA, distB);
}

float differenceSDF(float distA, float distB) 
{
    return max(distA, -distB);
}

float sphereSDF(vec3 point, float radius)
{
    return length(point) - radius;
}

float sceneSDF(vec3 point)
{   
    float sphere1 = sphereSDF(point - vec3(-1.5, 0., -2.), 1.);
    float sphere2 = sphereSDF(point - vec3(0., 0., -2.), 1.);
    float sphere3 = sphereSDF(point - vec3(1.5 + (1.+ sin(u_Time*2.)/2.)*0.7, 0., -2.), 1.);
    return unionSDF(unionSDF(sphere1, sphere2), sphere3);
}

vec3 get_ray(vec2 uv, float fov)
{
    vec2 norm_uv = uv*2. - 1.;
    float aspect_ratio = u_ImageSize.x / u_ImageSize.y;
    norm_uv.x *= aspect_ratio;
    norm_uv *= tan(fov / 2);
    
    vec3 image_point = norm_uv.x * u_CamRight + norm_uv.y * u_CamUp + u_CamForward;
    
    return normalize(image_point);
}

vec3 estimate_normal(vec3 pos)
{
    float dfdx = sceneSDF(vec3(pos.x+EPSILON,pos.y,pos.z))-sceneSDF(vec3(pos.x-EPSILON,pos.y,pos.z));
    float dfdy = sceneSDF(vec3(pos.x,pos.y+EPSILON,pos.z))-sceneSDF(vec3(pos.x,pos.y-EPSILON,pos.z));
    float dfdz = sceneSDF(vec3(pos.x,pos.y,pos.z+EPSILON))-sceneSDF(vec3(pos.x,pos.y,pos.z-EPSILON));
    return normalize(vec3(dfdx, dfdy, dfdz));
}

float dist_to_closest_point_to_surface(vec3 eye, vec3 ray, float end) 
{
    float depth = 0.;
    for (int i = 0; i < MARCH_STEPS; i++) {
        float dist = sceneSDF(eye + depth * ray);
        if (dist < EPSILON) {
			return depth;
        }
        depth += dist;
        if (depth >= end) {
            return end;
        }
    }
    return end;
}

void main() 
{
    //vec2 uv_scaled = vec2(v_Uv.x * u_ImageSize.x / u_ImageSize.y, v_Uv.y);
    //vec3 hit_color = max(vec3(0.3,sin(uv_scaled.x*50.+u_Time*10.),0.6),vec3(0.3,sin(uv_scaled.y*50.),0.6));
    const vec3 sun_dir = normalize(vec3(0.,-1.,1.));
    const vec3 scene_color = vec3(0.,0.5,0.);
    const float ambient = 0.1;

    vec3 ray = get_ray(v_Uv, radians(75.));
    //vec3 ray = rayDirection(45.0, u_ImageSize, u_ImageSize * v_Uv);
    vec3 hit_color = vec3(0);

    float dist = dist_to_closest_point_to_surface(u_CamPos, ray, MAX_DISTANCE);
    vec3 closest_to_surf = u_CamPos + ray * dist;

    if(sceneSDF(closest_to_surf)>=EPSILON)
    {
        Target0 = vec4(0.);
        return;
    }
    vec3 normal = estimate_normal(closest_to_surf);

    float diffuse = max(dot(normal, sun_dir), 0.0);

    hit_color = scene_color * (ambient + diffuse);

    
    Target0=vec4(hit_color,1.0);
}
