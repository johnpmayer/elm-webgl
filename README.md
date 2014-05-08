# WebGL for Elm

A simple API for rendering with WebGL. This is useful for both 2D and 3D
rendering because it lets you take advantage of hardware acceleration with the
GPU, meaning you can rendering things more quickly.

To get the most out of this library and out of the GPU, there are two general
concepts to understand: models and shaders.

### Models

A [model](http://en.wikipedia.org/wiki/3D_model) is all about shapes. It is a
collection of triangles that represents some 3-dimensional object. All shapes
can be approximated by placing small triangles side-by-side to build up larger
and more complex forms.

We create and update our models on the CPU, so working with a model does not get
any direct benefits from the GPU. To actually render these models, they are sent
from the CPU to the GPU. This transfer can be quite expensive, so it is best to
try to avoid it.

Some tricks to minimize this include breaking a model up into many smaller
pieces that can be transformed independently. For example, if you want to
render a skeleton, each bone could be a separate model, so rather than send
a new version of the entire model on every frame, you just send a
transformation matrix for each bone.

### Shaders

A [shader](http://en.wikipedia.org/wiki/Shader) is all about matching up models
with colors and textures. A shader is a program that runs on the GPU, so it
benefits from lots of parallelization. As a general rule, you want to be doing
computation here rather than on the CPU if possible.

In Elm, shaders are defined with a language called
[GLSL](http://en.wikipedia.org/wiki/OpenGL_Shading_Language). These are programs
that take in small high-level values and do a bunch of rendering based on that.
For example, you can send over a matrix that represents where the camera should
be and all of the models loded onto the GPU will be transformed accordingly.

To understand what is going on with shaders it is best to pair some examples
with a fairly solid understanding of how information flows through the rendering
pipeline. The rest of this section gives a high-level overview of the pipeline
and the terminology used to describe it.

There are two types of shaders used in Elm:

 * [**Vertex Shaders**](http://en.wikipedia.org/wiki/Shader#Vertex_shaders) &mdash;
   This runs once per vertex loaded into the GPU with the goal of flattening a
   point in 3D space into the 2D image to be shown on screen. This shader can
   manipulate things like the position, color, and texture of vertices.

 * [**Fragment Shaders**](http://en.wikipedia.org/wiki/Shader#Pixel_shaders) &mdash;
   Also known as pixel shaders, these shaders are like filters on individual
   pixels. They let you work with pixels to add lighting effects or add
   postprocessing effects like blur or edge-detection.

These shaders form a pipeline in which data flows from the CPU to the vertex
shader and finally to the fragment shader. To send information between shaders,
you use three kinds of specialized variables:

 * **Attribute** &mdash; these are read-only variables that are specific to
   a particular vertex. They are passed in from Elm and can only be used in
   the vertex shader.

 * **Uniform** &mdash; these are global read-only variables that can be used
   in both the vertex and fragment shaders.

 * **Varying** &mdash; these are variables you can write in the vertex shader
   which then get passed along into the fragment shader, where they are
   read-only. This lets you pass information along as you compute things in
   your rendering pipeline.
