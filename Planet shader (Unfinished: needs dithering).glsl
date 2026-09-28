const float PLANET_SIZE     = 0.42; //radius as a part of the screen
const float LIGHT_ANGLE     = 55.0;
const float LIGHT_HEIGHT    = 20.0;

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

#define HEX(h) (vec3(float(((h) >> 16) & 255), float(((h) >> 8) & 255), float((h) & 255)) / 255.0)
#define COL_DEEP      HEX(0x4a6cf0)
#define COL_SHALLOW   HEX(0x8fc0f0)
#define COL_LOWLAND   HEX(0x86d93a)
#define COL_HIGHLAND  HEX(0x46b36a)
#define COL_CLOUDS    HEX(0xeef3f6)
#define COL_SPACE     HEX(0x05060d)

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

vec3 rotY(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(c*p.x + s*p.z, p.y, -s*p.x + c*p.z); }
vec3 rotZ(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(c*p.x - s*p.y, s*p.x + c*p.y, p.z); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / (min(iResolution.x, iResolution.y) * PLANET_SIZE);
    float r2 = dot(uv, uv);
    float az = radians(LIGHT_ANGLE), el = radians(LIGHT_HEIGHT);
    vec3 L = normalize(vec3(cos(el) * sin(az), sin(el), cos(el) * cos(az)));

    vec3 col = COL_SPACE;
    if (r2 < 1.0) {
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

        vec3 cq = cp * vec3(CLOUD_SCALE, CLOUD_SCALE * 2.0, CLOUD_SCALE);   // stretched = banded clouds
        if (fbm(cq + SEED * 7.77 + 50.0) > 0.72 - CLOUD_COVER * 0.4) base = COL_CLOUDS;

        float lambert = max(dot(n, L), 0.0);
        col = base * (0.08 + 0.92 * lambert);
    }
    fragColor = vec4(col, 1.0);
}
