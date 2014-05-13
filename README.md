# WebGL for Elm

A simple API for rendering with WebGL. This is useful for both 2D and 3D
rendering because it lets you take advantage of hardware acceleration with the
GPU, meaning you can rendering things more quickly.

## Understanding WebGL

To get the most out of this library and out of the GPU, it is best to pair some
examples with a fairly solid understanding of how information flows through the
rendering pipeline. This section gives a high-level overview of the pipeline
and the corresponding terminology.

At a high-level, there are two general concepts to understand: meshes and
shaders. The details of each of these are crucial to using WebGL effectively.

### Meshes

A mesh is all about triangles. By placing small triangles side-by-side, you can
build up larger 3D shapes. We define each triangle by associating a bunch of
attributes&mdash;like position and color&mdash;with each corner of the triangle.

We create and update our meshes on the CPU, so working with a model does not get
any direct benefits from the GPU. Meshes are sent from the CPU to the GPU to be
rendered. This transfer can be quite expensive, so it is best to try to avoid
creating new meshes.

Some tricks to minimize this include breaking a mesh up into many smaller
pieces that can be transformed independently. For example, if you want to
render a skeleton, each bone could be a separate mesh, so rather than send
a new version of the entire skeleton on every frame, you just send a
transformation for each bone.

### Shaders

A [shader](http://en.wikipedia.org/wiki/Shader) is all turning meshes into
pictures. A shader is a program that runs on the GPU, so it benefits from
lots of parallelization. As a general rule, you want to be doing computation
here rather than on the CPU if possible.

In Elm, shaders are defined with a language called
[GLSL](http://en.wikipedia.org/wiki/OpenGL_Shading_Language). These are programs
that take in small high-level values and do a bunch of rendering based on that.
For example, you can send over a matrix that represents where the camera should
be and all of the meshes loded onto the GPU will be transformed accordingly.

### Combining Meshes and Shaders

The following diagram illustrates the entire pipeline. Keep reading past the
diagram, all the terms will be explained!

![WebGL Pipeline](/pipeline.png)

We start with a mesh. It's a bunch of raw data points that we want to render on
screen. From there, the data flows through two types of shaders:

 * [**Vertex Shaders**](http://en.wikipedia.org/wiki/Shader#Vertex_shaders) &mdash;
   Our mesh is made up of lots of triangles. Each corner of a triangle is called a
   *vertex*. The vertex shader has access to all of the attributes of each vertex,
   like position and color, letting us move triangles around or change their color.

 * [**Fragment Shaders**](http://en.wikipedia.org/wiki/Shader#Pixel_shaders) &mdash;
   Also known as pixel shaders, these shaders are like filters on individual
   pixels. They let you work with pixels to add lighting effects or add
   postprocessing effects like blur or edge-detection.

The flow of data between the CPU and each of our shaders is very well defined.
To send information, there are three kinds of specialized variables:

 * **Uniform** &mdash; these are global read-only variables that can be used
   in both the vertex and fragment shaders. They are defined on the CPU.

 * **Attribute** &mdash; these variables represent a particular vertex in our
   mesh. The vertex shader takes in these variables to compute some
   transformations on each vertex.

 * **Varying** &mdash; these are variables you can write in the vertex shader
   which then get passed along into the fragment shader, where they are
   read-only. This lets you pass information along as you compute things in
   your rendering pipeline.
