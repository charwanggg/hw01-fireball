#version 300 es
#pragma vscode_glsllint_stage : frag

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform vec4 u_Layer1Color;
uniform vec4 u_Layer2Color;
uniform vec4 u_Layer3Color;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec3 fs_ViewDir;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.


float fresnel(vec3 nor, vec3 view, float power) {
    float ndotv = clamp(
        dot(normalize(nor), normalize(view)),
        0.0,
        1.0
    );
    return pow(1.0 - ndotv, power);
}

float bias(float x, float b)
{
    return x / (((1.0 / b - 2.0) * (1.0 - x)) + 1.0);
}

float gain(float x, float g)
{
    if (x < 0.5)
        return bias(x * 2.0, g) * 0.5;
    else
        return bias(x * 2.0 - 1.0, 1.0 - g) * 0.5 + 0.5;
}
void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color;
        vec3 viewDir = normalize(fs_ViewDir);

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        // diffuseTerm = clamp(diffuseTerm, 0, 1);

        float ambientTerm = 0.2;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        // Compute final shaded color
        float fresOuter = fresnel(fs_Nor.xyz, fs_ViewDir, 5.0);
        fresOuter = max(gain(fresOuter, 0.4) - 0.2, 0.0);
        float fresMedium = fresnel(fs_Nor.xyz, fs_ViewDir, 2.0);

        vec4 innerColor = mix(u_Layer1Color, u_Layer2Color, fresMedium);
        vec4 fresnelColor = mix(innerColor, u_Layer3Color, fresOuter);
        
        out_Col = vec4(fresnelColor.xyz, 1.0);
        //out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
}
