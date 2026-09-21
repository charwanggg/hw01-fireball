import {vec3, vec4} from 'gl-matrix';
import Stats from 'stats-js';
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';

import lambertVertSource from './shaders/lambert-vert.glsl?raw';
import lambertFragSource from './shaders/lambert-frag.glsl?raw';

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  extinguishMode: false,
  out1Color: [255,216,0],
  out2Color: [255, 0, 49],
  out3Color: [255, 197, 158],
  'Load Scene': loadScene, // A function pointer, essentially
};

let icosphere: Icosphere;
let square: Square;
let prevTesselations: number = 5;

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'extinguishMode').name('Extinguish Mode');
  const layer1Color = gui.addColor(controls, 'out1Color').name('Layer 1 Color');
  const layer2Color = gui.addColor(controls, 'out2Color').name('Layer 2 Color');
  const layer3Color = gui.addColor(controls, 'out3Color').name('Layer 3 Color');
  gui.add({
    'Cold Mode': () => {
      controls.out1Color = [203, 235, 255];
      controls.out2Color = [0, 178, 255];
      controls.out3Color = [178, 226, 255];
      layer1Color.updateDisplay();
      layer2Color.updateDisplay();
      layer3Color.updateDisplay();
    },
  }, 'Cold Mode');

  gui.add({
    'Hot Mode': () => {
      controls.out1Color = [255,216,0];
      controls.out2Color = [255, 0, 49];
      controls.out3Color = [255, 197, 158];
      layer1Color.updateDisplay();
      layer2Color.updateDisplay();
      layer3Color.updateDisplay();
    },
  }, 'Hot Mode');
  gui.add(controls, 'Load Scene');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const mouse = {x: 0, y: 0, down: false};
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }

  canvas.addEventListener('pointermove', (event) => {
    const rect = canvas.getBoundingClientRect();
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = 1 - ((event.clientY - rect.top) / rect.height) * 2;
  });
  
  canvas.addEventListener('pointerdown', () => { mouse.down = true; });
  window.addEventListener('pointerup', () => { mouse.down = false; });

    const keys = new Set<string>();

    window.addEventListener('keydown', (event) => {
    keys.add(event.code);
    });

    window.addEventListener('keyup', (event) => {
    keys.delete(event.code);
    });


  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 7), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.2, 0.2, 0.2, 1);
  gl.enable(gl.DEPTH_TEST);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, lambertVertSource),
    new Shader(gl.FRAGMENT_SHADER, lambertFragSource),
  ]);

  function clamp(x: number, min: number, max: number): number {
    return Math.min(Math.max(x, min), max);
  }
  function lerp(a: number, b: number, t: number): number {
    return clamp(a + (b - a) * t, a, b);
  }

  let previousTime = performance.now();
  let noiseAmp = 0.1;
  let noiseSpeed = 3.0;
  // This function will be called every frame
  function tick() {
    const now = performance.now();
    const deltaTime = (now - previousTime) / 1000; 
    const lerpSpeed = 12.0;
    previousTime = now;

    camera.update();
    stats.begin();

    lambert.setTime(performance.now() * 0.001);

    if ((!controls.extinguishMode && keys.has('Space')) 
        || (controls.extinguishMode && !keys.has('Space'))) {
        noiseAmp = lerp(noiseAmp, 1.0, deltaTime * lerpSpeed);
        lambert.setNoiseModifiers(noiseAmp, 1.5);
    }
    else {
        let fps = 1 / deltaTime;
        noiseAmp = lerp(0.0, noiseAmp, 0.9);
        lambert.setNoiseModifiers(noiseAmp, 0.5);
    }
   
    lambert.setOut1Color(vec4.fromValues(
      controls.out1Color[0] / 255.0,
      controls.out1Color[1] / 255.0,
      controls.out1Color[2] / 255.0,
      1.0,
    ));
    lambert.setOut2Color(vec4.fromValues(
      controls.out2Color[0] / 255.0,
      controls.out2Color[1] / 255.0,
      controls.out2Color[2] / 255.0,
      1.0,
    ));
    lambert.setOut3Color(vec4.fromValues(
        controls.out3Color[0] / 255.0,
        controls.out3Color[1] / 255.0,
        controls.out3Color[2] / 255.0,
        1.0,
      ));

    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }
    renderer.render(camera, lambert, [
      icosphere,
      // square,
    ], vec4.fromValues(1, 1, 1, 1));
    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
