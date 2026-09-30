const float PIXEL_SIZE      = 4.0; 
const float PLANET_SIZE     = 0.42; //radius as a part of the screen
const float LIGHT_BANDS     = 3.0;    // brightness steps day -> night
const float DITHER          = 1.0;    // 0 = hard edges, 1 = full Bayer dither

const float LIGHT_ANGLE     = 55.0;
const float LIGHT_HEIGHT    = 20.0;
const float NIGHT_BRIGHT    = 1.0;

const float SPIN_SPEED      = 0.12; //radians/speed
const float CLOUD_SPEED     = 0.18; //radians/sec
const float AXIAL_TILT      = 18.0; //degrees

const float SEED            = 3.0;
const float TERRAIN_SCALE   = 2.2;
const int   DETAIL          = 5;
const float SEA_LEVEL       = 0.50;
const float SHALLOW_WIDTH   = 0.05;
const float HIGHLAND_HEIGHT = 0.08;

const float CLOUD_COVER     = 0.55;
const float CLOUD_SCALE     = 3.0;
const float CLOUD_STRETCH   = 2.0; 

const float ATMOSPHERE      = 0.06;   // glow ring thickness
const float STAR_DENSITY    = 0.4;  

#define HEX(h) (vec3(float(((h) >> 16) & 255), float(((h) >> 8) & 255), float((h) & 255)) / 255.0)
#define COL_DEEP      HEX(0x4a6cf0)
#define COL_SHALLOW   HEX(0x8fc0f0)
#define COL_LOWLAND   HEX(0x86d93a)
#define COL_HIGHLAND  HEX(0x46b36a)
#define COL_CLOUDS    HEX(0xeef3f6)
#define COL_SPACE     HEX(0x05060d)
#define COL_NIGHT     HEX(0x7a62d8)
#define COL_ATMO      HEX(0xf4f7ff)

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
        mix(mix(hash31(i),               hash31(i + vec3(1,0,0)), f.x),
            mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
            mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y),
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
vec3 rotZ(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(c*p.x - s*p.y, s*p.x + c*p.y, p.z); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 cell = floor(fragCoord / PIXEL_SIZE);
    vec2 fc   = (cell + 0.5) * PIXEL_SIZE;
    vec2 uv   = (fc - 0.5 * iResolution.xy) / (min(iResolution.x, iResolution.y) * PLANET_SIZE);
    float r2 = dot(uv, uv);
    float bay = bayer4(cell);

    float az = radians(LIGHT_ANGLE), el = radians(LIGHT_HEIGHT);
    vec3 L = normalize(vec3(cos(el) * sin(az), sin(el), cos(el) * cos(az)));

    float drag     = -iMouse.x / iResolution.x * 6.2832;
    float rot      = iTime * SPIN_SPEED  + drag;
    float cloudRot = iTime * CLOUD_SPEED + drag;

    vec3 col = COL_SPACE;
    float s = hash31(vec3(cell, 17.0));
    if (s > 1.0 - STAR_DENSITY * 0.01) {
        col = sin(iTime * 1.5 + s * 628.0) > -0.3 ? vec3(0.92) : vec3(0.45);
    }

    if (r2 < 1.0) {
        float z = sqrt(1.0 - r2);
        vec3 n  = vec3(uv, sqrt(1.0 - r2));
        vec3 t  = rotZ(n, radians(AXIAL_TILT));
        vec3 sp = rotY(t, iTime * SPIN_SPEED);
        vec3 cp = rotY(t, iTime * CLOUD_SPEED);

        float h = fbm(sp * TERRAIN_SCALE + SEED * 13.13);
        vec3 base;
        if      (h < SEA_LEVEL - SHALLOW_WIDTH)   base = COL_DEEP;
        else if (h < SEA_LEVEL)                   base = COL_SHALLOW;
        else if (h < SEA_LEVEL + HIGHLAND_HEIGHT) base = COL_LOWLAND;
        else                                      base = COL_HIGHLAND;

        vec3 cq = cp * vec3(CLOUD_SCALE, CLOUD_SCALE * 2.0, CLOUD_SCALE);  
        if (fbm(cq + SEED * 7.77 + 50.0) > 0.72 - CLOUD_COVER * 0.4) base = COL_CLOUDS;

        float lambert = dot(n, L);
        float lit     = clamp(lambert * 1.4 + 0.15, 0.0, 1.0);
        float stepped = clamp(floor(lit * LIGHT_BANDS + (bay - 0.5) * DITHER + 0.5) / LIGHT_BANDS, 0.0, 1.0);

        float lum = dot(base, vec3(0.299, 0.587, 0.114));
        vec3 nightCol = COL_NIGHT * (0.35 + 0.8 * lum) * NIGHT_BRIGHT;
        col = mix(nightCol, base, stepped);
        float rim = 1.0 - z;
        if (ATMOSPHERE > 0.0 && rim * clamp(lambert + 0.4, 0.0, 1.0) > 0.35 + bay * 0.5)
            col = mix(col, COL_ATMO, 0.6);
    } else if (ATMOSPHERE > 0.0) {
        float d = (sqrt(r2) - 1.0) / ATMOSPHERE;
        if (d < 1.0) {
            float facing = clamp(dot(vec3(normalize(uv), 0.0), L) * 0.7 + 0.3, 0.0, 1.0);
            if ((1.0 - d) * facing > bay) col = COL_ATMO;
        }
    }
    fragColor = vec4(col, 1.0);
}
