#include "ReShade.fxh"

//----------|
// :: UI :: |
//----------|

uniform float ShadowDensity <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 3.0; ui_step = 0.05;
    ui_label = "Shadow Density";
    ui_tooltip = "Darkening and cold tones strength. Better to tweak in dark interiors or night time.";
    ui_category = "Darkening";
> = 1.0;

uniform float VolumetricDepth <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
    ui_label = "Volumetric Strength (Distance)";
    ui_tooltip = "Extra darkening for distant pixels.";
    ui_category = "Darkening";
> = 2.0;

uniform float DepthCurve <
    ui_type = "drag";
    ui_min = 0.2; ui_max = 5.0; ui_step = 0.1;
    ui_label = "Distance Falloff Curve";
    ui_category = "Darkening";
> = 0.2;

uniform bool bUseVolumetric <
    ui_label = "Use Depth Buffer";
    ui_tooltip = "Disable in games where there is no depth access or troubles with depth.";
    ui_category = "Darkening";
> = true;

uniform float DepthSoftness <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 4.0; ui_step = 0.25;
    ui_label = "Volumetric Edge Softness";
    ui_tooltip = "";
    ui_category = "Darkening";
> = 1.5;

uniform float LightProtection <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
    ui_label = "Light Protection";
    ui_tooltip = "";
    ui_category = "Masks";
> = 0.40;

uniform float WarmProtection <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 10.0; ui_step = 0.05;
    ui_label = "Warm Tone Protection";
    ui_tooltip = "Protects warm colors from darkening.";
    ui_category = "Masks";
> = 3.0;

uniform float BlackAnchor <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.05;
    ui_label = "Pure Black Anchor";
    ui_tooltip = "Tweak up to your preferences and depend how shadows looks in your game.";
    ui_category = "Masks";
> = 0.50;

uniform float3 ShadowTint <
    ui_type = "color";
    ui_label = "Shadow Color Tint";
    ui_category = "Tint";
> = float3(0.02, 0.05, 0.12);

uniform float TintIntensity <
    ui_type = "drag";
    ui_min = 0.0; ui_max = 2.0; ui_step = 0.05;
    ui_label = "Tint Intensity";
    ui_category = "Tint";
> = 0.60;

//-----------------|
// :: Shader ::    |
//-----------------|


static const float MAX_DARKEN = 0.35;

float GetLuma(float3 rgb)
{
    return dot(rgb, float3(0.2126, 0.7152, 0.0722));
}

float GetLinearDepth(float2 uv)
{
    
    return ReShade::GetLinearizedDepth(uv);
}

float GetSmoothedLinearDepth(float2 uv)
{
    if (DepthSoftness <= 0.0)
        return GetLinearDepth(uv);

    const float2 px = ReShade::PixelSize * DepthSoftness;

    
    float depth = GetLinearDepth(uv) * 0.28;
    depth += (GetLinearDepth(uv + float2( px.x, 0.0)) +
              GetLinearDepth(uv + float2(-px.x, 0.0)) +
              GetLinearDepth(uv + float2(0.0,  px.y)) +
              GetLinearDepth(uv + float2(0.0, -px.y))) * 0.135;
    depth += (GetLinearDepth(uv + px) +
              GetLinearDepth(uv - px) +
              GetLinearDepth(uv + float2( px.x, -px.y)) +
              GetLinearDepth(uv + float2(-px.x,  px.y))) * 0.045;

    return depth;
}

void PS_AmbientDarkness(float4 vpos : SV_Position, float2 uv : TexCoord, out float4 outColor : SV_Target)
{
    float3 base = tex2D(ReShade::BackBuffer, uv).rgb;
    float luma = GetLuma(base);

    // --- Shadow mask -------------------------------------------------

    float lumaShadow = (1.0 - luma) * 0.5;

    float volDarkness = 0.0;
    if (bUseVolumetric)
        volDarkness = pow(GetSmoothedLinearDepth(uv), DepthCurve) * VolumetricDepth;

    
    float lumaFilter;
    if (LightProtection > 0.001)
        lumaFilter = 1.0 - smoothstep(LightProtection * 0.5, LightProtection, luma);
    else
        lumaFilter = 1.0;

    
    float warmth = saturate((base.r - base.b) * 2.0 + (base.g - base.b) * 0.5);
    float warmFilter = 1.0 - saturate(warmth * WarmProtection);

    
    
    float blackProtect = smoothstep(0.0, 0.1 * BlackAnchor + 1e-4, luma);

    float spatialMask = saturate(lumaShadow + volDarkness)
                      * lumaFilter * warmFilter * blackProtect;

    
    float darken = saturate(spatialMask * ShadowDensity) * MAX_DARKEN;
    float3 color = base * (1.0 - darken);

    
    float3 tinted = color + ShadowTint * (darken / MAX_DARKEN) * TintIntensity;

    outColor = float4(max(tinted, 0.0), 1.0);
}

technique AmbientDarkness <
    ui_label = "Sinitsa: AmbientNight";
    ui_tooltip = "";
>
{
    pass ApplySpatialDarkness
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_AmbientDarkness;
    }
}
