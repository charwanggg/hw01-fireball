#version 300 es
#pragma vscode_glsllint_stage : vert

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself
uniform vec3 u_CameraPos;
uniform float u_Time;
uniform float u_NoiseAmp;
uniform float u_NoiseSpeedModifier;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec3 fs_ViewDir;

const vec4 lightPos = vec4(5, 5, 3, 2); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.


float cubicPulse(float c, float w, float x) {
    x = abs(x - c);
    if (x > w) {
        return 0.0;
    }
    x /= w;
    return 1.0 - x * x * (3.0 - 2.0 * x);
}

float vertDisplacement(vec3 original) {
    if (original.y > 0.0) {
        return original.y * 1.3;
    }
    return original.y;
}

vec2 randomGradient(vec2 p)
{
    float angle = fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453)
                * 6.28318530718;

    return vec2(cos(angle), sin(angle));
}

float perlinNoise(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 g00 = randomGradient(i + vec2(0.0, 0.0));
    vec2 g10 = randomGradient(i + vec2(1.0, 0.0));
    vec2 g01 = randomGradient(i + vec2(0.0, 1.0));
    vec2 g11 = randomGradient(i + vec2(1.0, 1.0));

    float n00 = dot(g00, f - vec2(0.0, 0.0));
    float n10 = dot(g10, f - vec2(1.0, 0.0));
    float n01 = dot(g01, f - vec2(0.0, 1.0));
    float n11 = dot(g11, f - vec2(1.0, 1.0));
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float nx0 = mix(n00, n10, u.x);
    float nx1 = mix(n01, n11, u.x);

    return mix(nx0, nx1, u.y);
}

vec2 random2(vec2 p)
{
    return fract(sin(vec2(
        dot(p, vec2(127.1, 311.7)),
        dot(p, vec2(269.5, 183.3))
    )) * 43758.5453);
}

float voronoi(vec2 p)
{
    vec2 cell = floor(p);
    vec2 local = fract(p);

    float minDist = 10.0;

    // Check current cell and its 8 neighbors
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            vec2 neighbor = vec2(float(x), float(y));

            // Random point inside this neighboring cell
            vec2 point = random2(cell + neighbor);

            // Vector from our position to that point
            vec2 diff = neighbor + point - local;

            float dist = length(diff);

            minDist = min(minDist, dist);
        }
    }

    return minDist;
}


float bias(float x, float b)
{
    return x / (((1.0 / b - 2.0) * (1.0 - x)) + 1.0);
}

void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.

    vec4 modelposition = u_Model * vs_Pos;   // Temporarily store the transformed vertex positions for use below

    modelposition = vec4(modelposition.x, vertDisplacement(modelposition.xyz), modelposition.z, modelposition.w);
    vec2 perlinDir = vec2(1.0, 1.0);
    float perlinSpeed = 2.0;
    float perlinScale = 0.25;

    vec2 voronoiDir = vec2(-1.0, 1.0);
    float voronoiSpeed = 1.0;
    float voronoiScale = 0.5;

    float height = u_NoiseAmp * bias(1.0 - clamp(length(modelposition.xz), 0.0, 1.0), 0.4);
    if (fs_Nor.y > 0.0) {
        float noiseTime = u_Time * u_NoiseSpeedModifier;
        float noise = perlinNoise(modelposition.xz / perlinScale + perlinDir * perlinSpeed * noiseTime)
            + voronoi(modelposition.xz / voronoiScale + voronoiDir * voronoiSpeed * noiseTime);
        modelposition.y = modelposition.y + 1.3 * (height + (0.1 + 0.2 * u_NoiseAmp) * noise);
    }

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies
    fs_ViewDir = u_CameraPos - modelposition.xyz;    
    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
