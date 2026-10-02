const float PIXEL_SIZE      = 4.0;    
const float GALAXY_SIZE     = 0.45;  
const float BRIGHTNESS      = 1.5;    
const float DITHER          = 1.0;    

const int   ARMS            = 2;      
const float TWIST           = 3.0;    
const float ARM_WIDTH       = 2.5;    
const float CORE_SIZE       = 0.13;   
const float DISK_FALLOFF    = 1.7;    
const float TILT            = 55.0;   // degrees
const float ROLL            = 25.0;   // degrees

const float ROT_SPEED       = 0.05;   // radians/sec
const float NOISE_SCALE     = 4.0;    
const int   DETAIL          = 4;      // noise octaves (1-8)
const float DUST            = 0.5;    
const float DUST_SCALE      = 6.0;    
const float KNOTS           = 4.0;    // % of arm pixels that are pink star-forming knots

const float STAR_DENSITY    = 0.4;    // % of background pixels that are stars

#define HEX(h) (vec3(float(((h) >> 16) & 255), float(((h) >> 8) & 255), float((h) & 255)) / 255.0)
#define COL_OUTER   HEX(0x3b2a6b)
#define COL_ARM     HEX(0x5a74e6)
#define COL_BRIGHT  HEX(0xa8c8ff)
#define COL_CORE    HEX(0xfff1d6)
#define COL_KNOT    HEX(0xff7ab6)
#define COL_SPACE   HEX(0x05060d)


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

vec2 rot2(vec2 p, float a) { float c = cos(a), s = sin(a); return vec2(c*p.x - s*p.y, s*p.x + c*p.y); }

vec3 starfield(vec2 cell) {
    float s = hash31(vec3(cell, 17.0));
    if (s > 1.0 - STAR_DENSITY * 0.01)
        return sin(iTime * 1.5 + s * 628.0) > -0.3 ? vec3(0.92) : vec3(0.45);
    return COL_SPACE;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 cell = floor(fragCoord / PIXEL_SIZE);
    vec2 fc   = (cell + 0.5) * PIXEL_SIZE;
    vec2 uv   = (fc - 0.5 * iResolution.xy) / (min(iResolution.x, iResolution.y) * GALAXY_SIZE);
    float bay = bayer4(cell);

    vec2 p = rot2(uv, -radians(ROLL));
    p.y /= max(cos(radians(TILT)), 0.05);
    float r = length(p);

    float spin = iTime * ROT_SPEED;
    float ang  = atan(p.y, p.x) - spin;
    float s    = cos(float(ARMS) * (ang + TWIST * log(r + 1e-3)));
    float arm  = pow(0.5 + 0.5 * s, ARM_WIDTH);

    vec2 pr    = rot2(p, -spin);                     
    float n    = fbm(vec3(pr * NOISE_SCALE, 1.3));
    float dust = fbm(vec3(pr * DUST_SCALE, 7.1));

    float disk = exp(-r * DISK_FALLOFF);
    float core = exp(-(r * r) / (CORE_SIZE * CORE_SIZE));
    float b = BRIGHTNESS * (core * 1.3 + disk * (0.25 + 0.9 * arm) * (0.5 + n));
    b *= 1.0 - DUST * smoothstep(0.5, 0.7, dust) * (1.0 - core);

    float idx = floor(b * 4.0 + (bay - 0.5) * DITHER);

    vec3 col = starfield(cell);
    if      
        (idx >= 4.0) col = COL_CORE;
    else if 
        (idx >= 3.0) col = COL_BRIGHT;
    else if 
        (idx >= 2.0) col = COL_ARM;
    else if 
        (idx >= 1.0) col = COL_OUTER;

    if (idx >= 2.0 && arm > 0.6 && hash31(vec3(floor(pr * 60.0), 3.0)) > 1.0 - KNOTS * 0.01) 
        col = COL_KNOT;

    fragColor = vec4(col, 1.0);
}
