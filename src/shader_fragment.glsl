#version 150 core

const float PI = 3.14159265359;
const int MARCH_STEPS = 255;
const float EPSILON = 0.0001;
const float MAX_DISTANCE = 1000.;
const vec3 SUN_DIR = normalize(vec3(0.,1.,1.));
const float AMBIENT = 0.1;
const int REFLECTION_COUNT = 3;

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

struct ObjProps
{
    vec3 color;
    float reflectivity;
};

// SKYBOX
// Mathematical Constants
// Planet Constants
const float EARTHRADIUS = 6360e2; // 6360e3
const float ATMOSPHERERADIUS = 6420e2; //6420e3
const float SUNINTENSITY = 20.0; //20.0

// Rayleigh Scattering
const float RAYLEIGHSCALEHEIGHT = 7994.0; // 7994.0
const vec3 BETAR = vec3(3.8e-6, 13.5e-6, 33.1e-6);

// Mie Scattering
const float MIESCALEHEIGHT = 1200.0; // 1200.0
const vec3 BETAM = vec3(210e-5, 210e-5, 210e-5);
const float G = 0.76;

// --------------------------------------
// ---------- Helper Functions-----------
// --------------------------------------

// Returns the first intersection of the ray with the sphere (or -1.0 if no intersection)
// From https://gist.github.com/wwwtyro/beecc31d65d1004f5a9d

float raySphereIntersect(vec3 rayOrigin, vec3 rayDirection, vec3 sphereCenter, float sphereRadius) {
    
    float a = dot(rayDirection, rayDirection);
    vec3 d = rayOrigin - sphereCenter;
    float b = 2.0 * dot(rayDirection, d);
    float c = dot(d, d) - (sphereRadius * sphereRadius);
    if (b*b - 4.0*a*c < 0.0) {
        return -1.0;
    }
    return (-b + sqrt((b*b) - 4.0*a*c))/(2.0*a);
    
}

// -------------------------------
// ------- Main Functions --------
// -------------------------------

// The rayleigh phase function
float rayleighPhase(float mu) {
    float phase = (3.0 / (16.0 * PI)) * (1.0 + mu * mu);
    return phase;
}

// The mie phase function
float miePhase(float mu) {
    float numerator = (1.0 - G * G) * (1.0 + mu * mu);
    float denominator = (2.0 + G * G) * pow(1.0 + G * G - 2.0 * G * mu, 3.0/2.0);
    return (3.0 / (8.0 * PI)) * numerator / denominator;
}

// Returns the expected amount of atmospheric scattering at a given height above sea level
// Different parameters are passed in for rayleigh and mie scattering
vec3 scatteringAtHeight(vec3 scatteringAtSea, float height, float heightScale) {
	return scatteringAtSea * exp(-height/heightScale);
}

// Returns the height of a vector above the 'earth'
float height(vec3 p) {
    return (length(p) - EARTHRADIUS);
}

// Calculates the transmittance from pb to pa, given the scale height and the scattering
// coefficients. The samples parameter controls how accurate the result is.
// See the scratchapixel link for details on what is happening
vec3 transmittance(vec3 pa, vec3 pb, int samples, float scaleHeight, vec3 scatCoeffs) {
    float opticalDepth = 0.0;
    float segmentLength = length(pb - pa)/float(samples);
    for (int i = 0; i < samples; i++) {
        vec3 samplePoint = mix(pa, pb, (float(i)+0.5)/float(samples));
        float sampleHeight = height(samplePoint);
        opticalDepth += exp(-sampleHeight / scaleHeight) * segmentLength;
    }
    vec3 transmittance = exp(-1.0 * scatCoeffs * opticalDepth);
    return transmittance;
}

// This is the main function that uses the ideas of rayleigh and mie scattering
// This function is written with understandability in mind rather than performance, and
// redundant calls to transmittance can be removed as per the code in the scratchapixel link

vec3 getSkyColor(vec3 pa, vec3 pb, vec3 sunDir) {
	
    // Get the angle between the ray direction and the sun
    float mu = dot(normalize(pb - pa), sunDir);
    
    // Calculate the result from the phase functions
    float phaseR = rayleighPhase(mu);
    float phaseM = miePhase(mu);
    
    // Will be used to store the cumulative colors for rayleigh and mie
    vec3 rayleighColor = vec3(0.0, 0.0, 0.0);
    vec3 mieColor = vec3(0.0, 0.0, 0.0);

    // Performs an integral approximation by checking a number of sample points and:
    //		- Calculating the incident light on that point from the sun
    //		- Calculating the amount of that light that gets reflected towards the origin
    
    int samples = 10;
    float segmentLength = length(pb - pa) / float(samples);
    
    for (int i = 0; i < samples; i++) {
        
    	vec3 samplePoint = mix(pa, pb, (float(i)+0.5)/float(samples));
        float sampleHeight = height(samplePoint);
        float distanceToAtmosphere = raySphereIntersect(samplePoint, sunDir, vec3(0.0, 0.0, 0.0), ATMOSPHERERADIUS);
    	vec3 atmosphereIntersect = samplePoint + sunDir * distanceToAtmosphere;
        
        // Rayleigh Calculations
        vec3 trans1R = transmittance(pa, samplePoint, 10, RAYLEIGHSCALEHEIGHT, BETAR);
        vec3 trans2R = transmittance(samplePoint, atmosphereIntersect, 10, RAYLEIGHSCALEHEIGHT, BETAR);
        rayleighColor += trans1R * trans2R * scatteringAtHeight(BETAR, sampleHeight, RAYLEIGHSCALEHEIGHT) * segmentLength;
        
        // Mie Calculations
        vec3 trans1M = transmittance(pa, samplePoint, 10, MIESCALEHEIGHT, BETAM);
        vec3 trans2M = transmittance(samplePoint, atmosphereIntersect, 10, MIESCALEHEIGHT, BETAM);
        mieColor += trans1M * trans2M * scatteringAtHeight(BETAM, sampleHeight, MIESCALEHEIGHT) * segmentLength;
        
    }
    
    rayleighColor = SUNINTENSITY * phaseR * rayleighColor;
    mieColor = SUNINTENSITY * phaseM * mieColor;
    
    return rayleighColor + mieColor;
    
}

// Get the sky color for the ray in direction 'p'
vec3 skyColor(vec3 p, vec3 sunDir) {
    
    // Get the origin and direction of the ray
	vec3 origin = vec3(0.0, EARTHRADIUS + 1.0, 0.0);
	vec3 dir = p;

	// Get the position where the ray 'leaves' the atmopshere (see the scratchapixel link for details)
    // Note that this implementation only works when the origin is inside the atmosphere to begin with
    float distanceToAtmosphere = raySphereIntersect(origin, dir, vec3(0.0, 0.0, 0.0), ATMOSPHERERADIUS);
    vec3 atmosphereIntersect = origin + dir * distanceToAtmosphere;
    
    // Get the color of the light from the origin to the atmosphere intersect
    vec3 col = getSkyColor(origin, atmosphereIntersect, sunDir);
    return col;

}
// SKYBOX

float intersectSDF(in float distA, in float distB, in ObjProps colA, in ObjProps colB, out ObjProps colRes) 
{
    if(distA>distB)
    {
        colRes = colA;
        return distA;
    }
    else
    {
        colRes = colB;
        return distB;
    }
}

float unionSDF(in float distA, in float distB, in ObjProps colA, in ObjProps colB, out ObjProps colRes) 
{
    if(distA<distB)
    {
        colRes = colA;
        return distA;
    }
    else
    {
        colRes = colB;
        return distB;
    }
}

float differenceSDF(in float distA, in float distB, in ObjProps colA, in ObjProps colB, out ObjProps colRes) 
{
    return intersectSDF(distA,-distB,colA,colB,colRes);
}

vec3 repeat_point(in vec3 point, in vec3 frequency)
{
    vec3 q = mod(point, frequency)-0.5*frequency;
    return q;
}

float sphereSDF(in vec3 point, in float radius)
{
    return length(point) - radius;
}

float planeSDF(in vec3 point, in vec3 normal)
{
    return dot(normal, point);
}

float chessboard_color_intensity(in vec3 point)
{
    //add different dimensions 
    float chessboard = floor(point.x) + floor(point.y) + floor(point.z);
    //divide it by 2 and get the fractional part, resulting in a value of 0 for even and 0.5 for odd numbers.
    chessboard = fract(chessboard * 0.5);
    //multiply it by 2 to make odd values white instead of grey
    return chessboard * 2;
}

float sceneSDF(vec3 point, out ObjProps obj)
{
    float alotta_spheres = sphereSDF(repeat_point(point - vec3(0,1,0),vec3(2,0,2)), 0.2);
    ObjProps sphere_props = ObjProps(vec3(0,0.5,0.),0.01);

    float plane = planeSDF(point-vec3(0,0,0), vec3(0,1,0));
    float plane_stripes_freq = 1;
    float chessboard = chessboard_color_intensity(point*plane_stripes_freq);
    ObjProps res_obj = ObjProps(vec3(chessboard),0.9);

    return unionSDF(alotta_spheres, plane, sphere_props, res_obj, obj);
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
    ObjProps t;
    float dfdx = sceneSDF(vec3(pos.x+EPSILON,pos.y,pos.z), t)-sceneSDF(vec3(pos.x-EPSILON,pos.y,pos.z), t);
    float dfdy = sceneSDF(vec3(pos.x,pos.y+EPSILON,pos.z), t)-sceneSDF(vec3(pos.x,pos.y-EPSILON,pos.z), t);
    float dfdz = sceneSDF(vec3(pos.x,pos.y,pos.z+EPSILON), t)-sceneSDF(vec3(pos.x,pos.y,pos.z-EPSILON), t);
    return normalize(vec3(dfdx, dfdy, dfdz));
}

float dist_to_closest_point_to_surface(in vec3 eye, in vec3 ray, out ObjProps obj) 
{
    ObjProps t;
    float depth = 0.;
    for (int i = 0; i < MARCH_STEPS; i++) {
        float dist = sceneSDF(eye + depth * ray, t);
        if (dist < EPSILON) {
            obj = t;
			return depth;
        }
        depth += dist;
        if (depth >= MAX_DISTANCE) {
            obj = ObjProps(skyColor(ray, SUN_DIR), 0.);
            return MAX_DISTANCE;
        }
    }
    obj = ObjProps(skyColor(ray, SUN_DIR),0.);
    return MAX_DISTANCE;
}

void main() 
{
    vec3 ray = get_ray(v_Uv, radians(75.));

    ObjProps hit_obj;
    float dist = dist_to_closest_point_to_surface(u_CamPos, ray, hit_obj);
    vec3 closest_to_surf = u_CamPos + ray * dist;
    if(dist < MAX_DISTANCE)
    {
        vec3 normal = estimate_normal(closest_to_surf);
        float diffuse = max(dot(normal, SUN_DIR), 0.0);

        float potential_reflectivity = 1.;
        vec3 res_col = hit_obj.color * (AMBIENT + diffuse);
        ObjProps refl_obj = hit_obj;
        vec3 hit_pos = closest_to_surf;
        vec3 hit_normal = normal;
        vec3 refl_dir = ray;
        for (int i = 1; i <= REFLECTION_COUNT; i++) 
        {
            ObjProps prev_refl_obj = refl_obj;
            refl_dir = reflect(refl_dir,hit_normal);
            float refl_dist = dist_to_closest_point_to_surface(hit_pos+refl_dir*0.01, refl_dir, refl_obj);
            hit_pos = hit_pos + refl_dir * refl_dist;
            hit_normal = estimate_normal(hit_pos);
            float refl_diffuse = max(dot(hit_normal, SUN_DIR), 0.0);
            potential_reflectivity *= prev_refl_obj.reflectivity;
            res_col = mix(res_col, refl_obj.color * (AMBIENT + refl_diffuse), potential_reflectivity);
            if(refl_dist>=MAX_DISTANCE)
                break;
        }

        hit_obj.color = res_col;
    }
    Target0=vec4(hit_obj.color,1.0);
}
