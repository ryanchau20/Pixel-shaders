const float PIXEL_SIZE      = 4.0;   
const float PLANET_SIZE     = 0.20;   // radius as fraction of screen
const float LIGHT_BANDS     = 3.0;  
const float DITHER          = 1.0;    // 0 = hard edges, 1 = full Bayer dither

const float SPIN_SPEED      = 0.15;   // radians/sec
const float BAND_COUNT      = 7.0; 
const float TURBULENCE      = 0.6;   
const float TURB_SCALE      = 2.0;    // bigger = smaller swirls
const int   DETAIL          = 4;      // noise octaves (1-8)
const float STORM_SIZE      = 0.18;  
const float STORM_LAT       = -0.35;  // -1 south pole ... 1 north pole

const float RING_OPEN       = 18.0;   // degrees: 0 = edge-on, 90 = face-on
const float RING_ROLL       = -15.0;  // degrees of on-screen tilt
const float RING_INNER      = 1.35;   // in planet radii
const float RING_OUTER      = 2.20;   // in planet radii
const float RING_BANDS      = 14.0; 
const float RING_GAPS       = 0.30;   // 0 = solid, 1 = mostly gaps

const float LIGHT_ANGLE     = 50.0;   // degrees around planet
const float LIGHT_HEIGHT    = 25.0;   // degrees above/below
const float NIGHT_BRIGHT    = 1.0; 

const float STAR_DENSITY    = 0.4;    // % of background pixels that are stars

#define HEX(h) (vec3(float(((h) >> 16) & 255), float(((h) >> 8) & 255), float((h) & 255)) / 255.0)
#define COL_BAND_1  HEX(0xe8c89a)
#define COL_BAND_2  HEX(0xc98b5a)
#define COL_BAND_3  HEX(0xf3e6cf)
#define COL_BAND_4  HEX(0x9c5b43)
#define COL_STORM   HEX(0xd9573b)
#define COL_RING_1  HEX(0xd9c7a3)
#define COL_RING_2  HEX(0x8f7b62)
#define COL_NIGHT   HEX(0x4b3a7a)
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

vec3 rotX(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x, c*p.y - s*p.z, s*p.y + c*p.z); }
vec3 rotY(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(c*p.x + s*p.z, p.y, -s*p.x + c*p.z); }
vec3 rotZ(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(c*p.x - s*p.y, s*p.x + c*p.y, p.z); }

vec3 starfield(vec2 cell) {
    float s = hash31(vec3(cell, 17.0));
    if (s > 1.0 - STAR_DENSITY * 0.01)
        return sin(iTime * 1.5 + s * 628.0) > -0.3 ? vec3(0.92) : vec3(0.45);
    return COL_SPACE;
}

float ringDensity(float rr) {
    if (rr < RING_INNER || rr > RING_OUTER) return 0.0;
    float d = vnoise(vec3(rr * RING_BANDS, 0.5, 0.5)) * 0.7 + vnoise(vec3(rr * RING_BANDS * 3.1, 4.5, 0.5)) * 0.3;
    return smoothstep(0.25, 0.75, d);
}

vec3 shade(vec3 base, float lit, float bay) {
    float stepped = clamp(floor(lit * LIGHT_BANDS + (bay - 0.5) * DITHER + 0.5) / LIGHT_BANDS, 0.0, 1.0);
    float lum = dot(base, vec3(0.299, 0.587, 0.114));
    vec3 nightCol = COL_NIGHT * (0.35 + 0.8 * lum) * NIGHT_BRIGHT;
    return mix(nightCol, base, stepped);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 cell = floor(fragCoord / PIXEL_SIZE);
    vec2 fc   = (cell + 0.5) * PIXEL_SIZE;
    vec2 uv   = (fc - 0.5 * iResolution.xy) / (min(iResolution.x, iResolution.y) * PLANET_SIZE);
    float r2  = dot(uv, uv);
    float bay = bayer4(cell);

    float az = radians(LIGHT_ANGLE), el = radians(LIGHT_HEIGHT);
    vec3 L = normalize(vec3(cos(el) * sin(az), sin(el), cos(el) * cos(az)));
    float openA = radians(RING_OPEN), rollA = radians(RING_ROLL);
    vec3 N = rotZ(rotX(vec3(0.0, 1.0, 0.0), openA), rollA);  

    vec3 col = starfield(cell);

    bool onDisc = r2 < 1.0;
    float zs = onDisc ? sqrt(1.0 - r2) : -1e9;

    if (onDisc) {
        vec3 n  = vec3(uv, zs);
        vec3 pl = rotX(rotZ(n, -rollA), -openA);             
        vec3 sp = rotY(pl, iTime * SPIN_SPEED);

        float t = fbm(sp * TURB_SCALE + vec3(0.0, 0.0, iTime * 0.02));
        float b = sp.y * BAND_COUNT + (t - 0.5) * TURBULENCE * 4.0;
        float idx = mod(floor(b), 4.0);
        vec3 base = idx < 0.5 ? COL_BAND_1 : idx < 1.5 ? COL_BAND_2 : idx < 2.5 ? COL_BAND_3 : COL_BAND_4;

        vec3 dd = sp - normalize(vec3(0.0, STORM_LAT, 1.0));
        dd.y *= 1.8;
        float ds = length(dd) / max(STORM_SIZE, 1e-4);
        if (STORM_SIZE > 0.0 && ds < 1.0) base = ds < 0.6 ? COL_STORM : COL_BAND_3;

        float lambert = dot(n, L);
        float lit = clamp(lambert * 1.4 + 0.15, 0.0, 1.0);

        float dn = dot(L, N);
        if (abs(dn) > 1e-3) {
            float tt = -dot(n, N) / dn;
            if (tt > 0.0 && ringDensity(length(n + tt * L)) > RING_GAPS) lit *= 0.3;
        }
        col = shade(base, lit, bay);
    }

    if (abs(N.z) > 1e-3) {
        float zp = -(uv.x * N.x + uv.y * N.y) / N.z;
        vec3 p   = vec3(uv, zp);
        float rr = length(p);
        float dens = ringDensity(rr);
        if (dens > RING_GAPS && zp > zs) {
            vec3 rc = dens > 0.6 ? COL_RING_1 : COL_RING_2;
            float pL = dot(p, L);
            vec3 perp = p - pL * L;
            if (pL < 0.0 && dot(perp, perp) < 1.0) rc = shade(rc, 0.0, bay);
            col = rc;
        }
    }

    fragColor = vec4(col, 1.0);
}
