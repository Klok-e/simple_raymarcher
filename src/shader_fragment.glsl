#version 150 core

const float PI = 3.14159265359;
const int MARCH_STEPS = 20;
const float MARCH_HIT_THRESHOLD = 0.000001;
const float EPSILON = 0.001;
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

float sphereSDF(vec3 point, vec3 sphereCentre, float radius)
{
    vec3 pointToCentre = point - sphereCentre;
    return dot(pointToCentre, pointToCentre) - radius * radius;
}

float sceneSDF(vec3 point)
{
    return sphereSDF(point, vec3(0., 0., 2.), 1.4);
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

/**
 * Lighting contribution of a single point light source via Phong illumination.
 * 
 * The vec3 returned is the RGB color of the light's contribution.
 *
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 * lightPos: the position of the light
 * lightIntensity: color/intensity of the light
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
vec3 phongContribForLight(vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye,
                          vec3 lightPos, vec3 lightIntensity) {
    vec3 N = estimate_normal(p);
    vec3 L = normalize(lightPos - p);
    vec3 V = normalize(eye - p);
    vec3 R = normalize(reflect(-L, N));
    
    float dotLN = dot(L, N);
    float dotRV = dot(R, V);
    
    if (dotLN < 0.0) {
        // Light not visible from this point on the surface
        return vec3(0.0, 0.0, 0.0);
    } 
    
    if (dotRV < 0.0) {
        // Light reflection in opposite direction as viewer, apply only diffuse
        // component
        return lightIntensity * (k_d * dotLN);
    }
    return lightIntensity * (k_d * dotLN + k_s * pow(dotRV, alpha));
}

/**
 * Lighting via Phong illumination.
 * 
 * The vec3 returned is the RGB color of that point after lighting is applied.
 * k_a: Ambient color
 * k_d: Diffuse color
 * k_s: Specular color
 * alpha: Shininess coefficient
 * p: position of point being lit
 * eye: the position of the camera
 *
 * See https://en.wikipedia.org/wiki/Phong_reflection_model#Description
 */
vec3 phongIllumination(vec3 k_a, vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye) {
    const vec3 ambientLight = 0.5 * vec3(1.0, 1.0, 1.0);
    vec3 color = ambientLight * k_a;
    
    vec3 light1Pos = vec3(4.0 * sin(u_Time),
                          2.0,
                          4.0 * cos(u_Time));
    vec3 light1Intensity = vec3(0.4, 0.4, 0.4);
    
    color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                  light1Pos,
                                  light1Intensity);
    
    vec3 light2Pos = vec3(2.0 * sin(0.37 * u_Time),
                          2.0 * cos(0.37 * u_Time),
                          2.0);
    vec3 light2Intensity = vec3(0.4, 0.4, 0.4);
    
    color += phongContribForLight(k_d, k_s, alpha, p, eye,
                                  light2Pos,
                                  light2Intensity);    
    return color;
}

float shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) 
{
    float depth = start;
    for (int i = 0; i < MARCH_STEPS; i++) {
        float dist = sceneSDF(eye + depth * marchingDirection);
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

    vec3 ray = get_ray(v_Uv, radians(75.));
    vec3 hit_color = vec3(0);

    float dist = shortestDistanceToSurface(u_CamPos, ray, 0., MAX_DISTANCE);
    vec3 closest_to_surf = u_CamPos + ray * dist;

    if(sceneSDF(closest_to_surf)>MARCH_HIT_THRESHOLD)
    {
        Target0 = vec4(0.);
        return;
    }

    vec3 K_a = vec3(0.2, 0.2, 0.2);
    vec3 K_d = vec3(0.7, 0.2, 0.2);
    vec3 K_s = vec3(1.0, 1.0, 1.0);
    float shininess = 10.0;
    
    hit_color = phongIllumination(K_a, K_d, K_s, shininess, closest_to_surf, u_CamPos);
    
    Target0=vec4(hit_color,1.0);
}
