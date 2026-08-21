
#include "ReShade.fxh"	

//----------|
// :: UI :: |
//----------|

uniform float ShadowDensity <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 3.0; ui_step = 0.05;
    ui_label = "Shadow Density";
> = 0.5;

uniform float VolumetricDepth <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
    ui_label = "Volumetric Darkness (Distance)";
> = 2.0;

uniform float DepthCurve <
    ui_type = "drag";
    ui_min = 0.2; ui_max = 5.0; ui_step = 0.1;
    ui_label = "Distance Falloff Curve";
> = 0.2;

uniform float LightProtection <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
    ui_label = "Light Protection";
> = 0.40;

uniform float WarmProtection <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 10.0; ui_step = 0.05;
    ui_label = "Warm Tone Protection";
    ui_tooltip = "Tweak it untill warm colors would be the same as if without shader.";
> = 3.0;

uniform float3 ShadowTint <
    ui_type = "color";
    ui_label = "Shadow Color Tint";
> = float3(0.02, 0.05, 0.12);

uniform float TintIntensity <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
    ui_label = "Tint Intensity";
> = 0.60;

uniform float BlackAnchor <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
    ui_label = "Pure Black Anchor";
    ui_tooltip = "Tweak it if some shadows looks weird.";
> = 0.50;

//-------------------|
// :: Textures ::    |
//-------------------|

namespace AmbientDarkness
{
    texture TexDepth : DEPTH;
    sampler sTexDepth 
    { 
        Texture = TexDepth; 
        MinFilter = POINT;
        MagFilter = POINT;
        MipFilter = POINT;
    };

    float GetLuma(float3 rgb)
    {
        return dot(rgb, float3(0.2126, 0.7152, 0.0722));
    }

    float GetLinearDepth(float2 uv)
    {
        float depth = tex2Dlod(sTexDepth, float4(uv, 0.0, 0.0)).r;

        #if RESHADE_DEPTH_INPUT_IS_REVERSED
            depth = 1.0 - depth;
        #endif

        #ifndef RESHADE_DEPTH_LINEARIZATION_FAR_PLANE
            #define RESHADE_DEPTH_LINEARIZATION_FAR_PLANE 1000.0
        #endif

        const float farPlane = RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
        depth = depth / (farPlane - depth * (farPlane - 1.0));

        return saturate(depth);
    }

    void PS_ApplySpatialDarkness(float4 vpos : SV_Position, float2 uv : TexCoord, out float4 outColor : SV_Target)
    {
        float3 base = tex2D(ReShade::BackBuffer, uv).rgb;
        float luma = GetLuma(base);
        float depth = GetLinearDepth(uv);

        
        float lumaShadow = (1.0 - luma) * 0.5;
        float volDarkness = pow(depth, DepthCurve) * VolumetricDepth;
        float lumaFilter = smoothstep(LightProtection, 0.02, luma);

        float spatialMask = saturate(lumaShadow + volDarkness) * lumaFilter;

        
        float compress = 1.0 - (spatialMask * ShadowDensity * 0.35);
        float3 denseColor = base * compress;

        
        
        float warmness = saturate((base.r - base.b) * 2.0 + (base.g - base.b) * 0.5);
        float warmFilter = lerp(1.0, 1.0 - warmness, WarmProtection);

        
        float anchor = smoothstep(0.0, 0.05 * (1.0 - BlackAnchor + 0.001), luma);
        
        
        float tintAmount = spatialMask * TintIntensity * anchor * warmFilter;

        denseColor = lerp(denseColor, denseColor + ShadowTint * (1.0 - luma), tintAmount);

        outColor = float4(max(0.0, denseColor), 1.0);
    }

    technique AmbientDarkness
    <
        ui_label = "Sinitsa: AmbientNight";
        ui_tooltip = "";
    >
    {
        pass ApplySpatialDarkness
        {
            VertexShader = PostProcessVS;
            PixelShader = PS_ApplySpatialDarkness;
        }
    }
}