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

float map(in vec3 p, out vec4 resColor )
{
    vec3 w = p;
    float m = dot(w,w);

    vec4 trap = vec4(abs(w),m);
	float dz = 1.0;
    
    
	for( int i=0; i<4; i++ )
    {
#if 0
        float m2 = m*m;
        float m4 = m2*m2;
		dz = 8.0*sqrt(m4*m2*m)*dz + 1.0;

        float x = w.x; float x2 = x*x; float x4 = x2*x2;
        float y = w.y; float y2 = y*y; float y4 = y2*y2;
        float z = w.z; float z2 = z*z; float z4 = z2*z2;

        float k3 = x2 + z2;
        float k2 = inversesqrt( k3*k3*k3*k3*k3*k3*k3 );
        float k1 = x4 + y4 + z4 - 6.0*y2*z2 - 6.0*x2*y2 + 2.0*z2*x2;
        float k4 = x2 - y2 + z2;

        w.x = p.x +  64.0*x*y*z*(x2-z2)*k4*(x4-6.0*x2*z2+z4)*k1*k2;
        w.y = p.y + -16.0*y2*k3*k4*k4 + k1*k1;
        w.z = p.z +  -8.0*y*k4*(x4*x4 - 28.0*x4*x2*z2 + 70.0*x4*z4 - 28.0*x2*z2*z4 + z4*z4)*k1*k2;
#else
        dz = 8.0*pow(sqrt(m),7.0)*dz + 1.0;
		//dz = 8.0*pow(m,3.5)*dz + 1.0;
        
        float r = length(w);
        float b = 8.0*acos( w.y/r);
        float a = 8.0*atan( w.x, w.z );
        w = p + pow(r,8.0) * vec3( sin(b)*sin(a), cos(b), sin(b)*cos(a) );
#endif        
        
        trap = min( trap, vec4(abs(w),m) );

        m = dot(w,w);
		if( m > 256.0 )
            break;
    }

    resColor = vec4(m,trap.yzw);

    return 0.25*log(m)*sqrt(m)/dz;
}

float sceneSDF_3spheres(vec3 point)
{   
    float sphere1 = sphereSDF(point - vec3(-2., 0., -2.), 1.);
    float sphere2 = sphereSDF(point - vec3(0., 0., -2.), 1.);
    float sphere3 = sphereSDF(point - vec3(1.5 + (1.+ sin(u_Time*2.)/2.)*0.7, 0., -2.), 1.);
    return unionSDF(unionSDF(sphere1, sphere2), sphere3);
}

float sceneSDF(vec3 point, out vec4 color)
{
    return map(point, color);
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
    vec4 t;
    float dfdx = sceneSDF(vec3(pos.x+EPSILON,pos.y,pos.z), t)-sceneSDF(vec3(pos.x-EPSILON,pos.y,pos.z), t);
    float dfdy = sceneSDF(vec3(pos.x,pos.y+EPSILON,pos.z), t)-sceneSDF(vec3(pos.x,pos.y-EPSILON,pos.z), t);
    float dfdz = sceneSDF(vec3(pos.x,pos.y,pos.z+EPSILON), t)-sceneSDF(vec3(pos.x,pos.y,pos.z-EPSILON), t);
    return normalize(vec3(dfdx, dfdy, dfdz));
}

float dist_to_closest_point_to_surface(vec3 eye, vec3 ray, float end) 
{
    vec4 t;
    float depth = 0.;
    for (int i = 0; i < MARCH_STEPS; i++) {
        float dist = sceneSDF(eye + depth * ray, t);
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
    const vec3 sun_dir = normalize(vec3(0.,1.,1.));
    const float ambient = 0.1;

    vec3 ray = get_ray(v_Uv, radians(75.));
    //vec3 ray = rayDirection(45.0, u_ImageSize, u_ImageSize * v_Uv);
    vec3 hit_color = vec3(0);

    float dist = dist_to_closest_point_to_surface(u_CamPos, ray, MAX_DISTANCE);
    vec3 closest_to_surf = u_CamPos + ray * dist;

    if(dist > MAX_DISTANCE)
    {
        Target0 = vec4(0.);
        return;
    }
    vec4 obj_color;
    sceneSDF(closest_to_surf, obj_color);

    vec3 normal = estimate_normal(closest_to_surf);
    float diffuse = max(dot(normal, sun_dir), 0.0);

    hit_color = obj_color.xyz * (ambient + diffuse);

    Target0=vec4(hit_color,1.0);
}
