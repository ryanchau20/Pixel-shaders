const float PIXEL_SIZE      = 4.0;    
const float STAR_SIZE       = 0.30;   
const float DITHER          = 1.0;    

const float SPIN_SPEED      = 0.08;   // radians/sec
const float SURFACE_SCALE   = 3.0;   
const float BOIL_SPEED      = 0.25;   
const int   DETAIL          = 5;      // noise octaves (1-8)
const float LIMB_DARKENING  = 0.7;    

const float CORONA_SIZE     = 0.45;   // reach of flames, in star radii
const float FLARE_SCALE     = 3.0;    
const float CORONA_SPEED    = 0.35;   

const float STAR_DENSITY    = 0.4;    

#define HEX(h) (vec3(float(((h) >> 16) & 255), float(((h) >> 8) & 255), float((h) & 255)) / 255.0)
#define COL_CORE        HEX(0xfff6c8)
#define COL_HOT         HEX(0xffd23f)
#define COL_MID         HEX(0xff8a1f)
#define COL_COOL        HEX(0xc7361f)
#define COL_CORONA_IN   HEX(0xffb347)
#define COL_CORONA_OUT  HEX(0x8a2a5c)
#define COL_SPACE       HEX(0x05060d)

float hash31(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash31(i),                   hash31(i + vec3(1,0,0)), f.x),
            mix(hash31(i + vec3(0,1,0)),     hash31(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash31(i + vec3(0,0,1)),     hash31(i + vec3(1,0,1)), f.x),
            mix(hash31(i + vec3(0,1,1)),     hash31(i + vec3(1,1,1)), f.x), f.y),
        f.z);
}

float fbm(vec3 p) {
    float sum = 0.0, amp = 0.5, norm = 0.0;
    for (int i = 0; i < DETAIL; i++) {
        sum  += amp * vnoise(p);
        norm += amp;
        p = p * 2.03 + vec3(1.7, 9.2, 3.1);
        amp *= 0.5;
    }
    return sum / norm;
}

float bayer2(vec2 a) { a = floor(a); return fract(dot(a, vec2(0.5, a.y * 0.75))); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }

vec3 rotY(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(c*p.x + s*p.z, p.y, -s*p.x + c*p.z); }

vec3 starfield(vec2 cell) {
    float s = hash31(vec3(cell, 17.0));
    if (s > 1.0 - STAR_DENSITY * 0.01)
        return sin(iTime * 1.5 + s * 628.0) > -0.3 ? vec3(0.92) : vec3(0.45);
    return COL_SPACE;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 cell = floor(fragCoord / PIXEL_SIZE);
    vec2 fc   = (cell + 0.5) * PIXEL_SIZE;
    vec2 uv   = (fc - 0.5 * iResolution.xy) / (min(iResolution.x, iResolution.y) * STAR_SIZE);
    float r2  = dot(uv, uv);
    float bay = bayer4(cell);

    vec3 col = starfield(cell);

    if (r2 < 1.0) {
        float z  = sqrt(1.0 - r2);
        vec3 sp  = rotY(vec3(uv, z), iTime * SPIN_SPEED);
        vec3 q   = sp * SURFACE_SCALE;

        float w = fbm(q + vec3(0.0, 0.0, iTime * BOIL_SPEED));
        float v = fbm(q * 1.7 + w * 2.0 - vec3(iTime * BOIL_SPEED * 0.6, 0.0, 0.0));
        v = clamp((v - 0.3) / 0.4, 0.0, 1.0);

        float limb = mix(1.0, pow(z, 0.5), LIMB_DARKENING);
        float b    = limb * (0.45 + 0.7 * v);

        float idx = clamp(floor(b * 4.0 + (bay - 0.5) * DITHER), 0.0, 3.0);
        col = idx < 0.5 ? COL_COOL : idx < 1.5 ? COL_MID : idx < 2.5 ? COL_HOT : COL_CORE;
    } else {
        float r = sqrt(r2);
        float d = (r - 1.0) / CORONA_SIZE;
        if (d < 1.6) {
            vec2 dir = uv / r;
            float n  = fbm(vec3(dir * FLARE_SCALE, d * 1.5 - iTime * CORONA_SPEED));
            float I  = (1.0 - d) + (n - 0.5) * 1.8;
            float t  = I + (bay - 0.5) * 0.4 * DITHER;
            
            if      (t > 0.70) 
                col = COL_CORONA_IN;
            else if (t > 0.35) 
                col = COL_CORONA_OUT;
        }
    }

    fragColor = vec4(col, 1.0);
}
