Elm.Native.WebGL = {};
Elm.Native.WebGL.make = function(elm) {

  elm.Native = elm.Native || {};
  elm.Native.Graphics = elm.Native.Graphics || {};
  elm.Native.WebGL = elm.Native.WebGL || {};
  if (elm.Native.WebGL.values) {
      return elm.Native.WebGL.values;
  }

  // setup logging
  function LOG(msg) {
    // console.log(msg);
  }

  var createNode = Elm.Native.Graphics.Element.make(elm).createNode;
  var newElement = Elm.Native.Graphics.Element.make(elm).newElement;

  var List   = Elm.List.make(elm);
  var Utils  = Elm.Native.Utils.make(elm);
  var Signal = Elm.Signal.make(elm);
  var Tuple2 = Utils.Tuple2;
  var Task   = Elm.Native.Task.make(elm);

  function unsafeCoerceGLSL(src) {
    return { src : src };
  }

  function loadTexture(source) {
    return Task.asyncFunction(function(callback) {
      var img = new Image();
      img.onload = function() {
        return callback(Task.succeed({img:img}));
      };
      img.onerror = function(e) {
        return callback(Task.fail({ ctor: 'Error' }));
      };
      img.src = source;
    });
  }

  function entity(primitive, vert, frag, buffer, uniforms) {

    if (!buffer.guid) {
      buffer.guid = Utils.guid();
    }

    return {
      vert: vert,
      frag: frag,
      buffer: buffer,
      uniforms: uniforms,
      primitive: primitive
    };

  }

  function trianglesEntity(v, f, b, u) { return entity("TRIANGLES", v, f, b, u); }
  function linesEntity(v, f, b, u) { return entity("LINES", v, f, b, u); }
  function pointsEntity(v, f, b, u) { return entity("POINTS", v, f, b, u); }

  function do_texture (gl, img) {

    var tex = gl.createTexture();
    LOG("Created texture");
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.generateMipmap(gl.TEXTURE_2D);
    //gl.bindTexture(gl.TEXTURE0, null);
    return tex;

  }

  function do_compile (gl, src, tipe) {

    var shader = gl.createShader(tipe);
    LOG("Created shader");

    gl.shaderSource(shader, src);
    gl.compileShader(shader);
    var compile = gl.COMPILE_STATUS;
    if (!gl.getShaderParameter(shader,compile)) {
      throw gl.getShaderInfoLog(shader);
    }

    return shader;

  }

  function do_link (gl, vshader, fshader) {

    var program = gl.createProgram();
    LOG("Created program");

    gl.attachShader(program, vshader);
    gl.attachShader(program, fshader);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(program);
    }

    return program;

  }

  function pusher_function(data, name, n_elems_tuple, n_dims) {
    f = "(function(elem) { ";
    if(n_elems_tuple === 1) {
      for(var d=0; d<n_dims; d++)
        f += "data.push(elem[name][" + d + "]); ";
    } else {
      for(var i=0; i<n_elems_tuple; i++)
        for(var d=0; d<n_dims; d++)
         f += "data.push(elem._" + i + "[name][" + d + "]); ";
    }
    f += "})"
    return eval(f);
  }

  function do_bind (gl, program, bufferElems, primitive) {

    var buffers = {};

    var n_elems_tuple;
    switch (primitive) {
      case gl.POINTS:    n_elems_tuple = 1; break;
      case gl.LINES:     n_elems_tuple = 2; break;
      case gl.TRIANGLES: n_elems_tuple = 3; break;
      default: LOG("Bad primitive type"); break;
    }

    var attributes = gl.getProgramParameter(program, gl.ACTIVE_ATTRIBUTES);
    for (var i = 0; i < attributes; i += 1) {
      var attribute = gl.getActiveAttrib(program, i);
      var n_dims;
      switch (attribute.type) {
        case gl.FLOAT_VEC2: n_dims = 2; break;
        case gl.FLOAT_VEC3: n_dims = 3; break;
        case gl.FLOAT_VEC4: n_dims = 4; break;
        default: LOG("Bad buffer type"); break;
      }

      // Might want to invert the loop
      // to build the array buffer first
      // and then bind each one-at-a-time
      var data = [];
      A2(List.map,
         pusher_function(data, attribute.name, n_elems_tuple, n_dims),
         bufferElems);
      var array = new Float32Array(data);
      console.log(array);

      var buffer = gl.createBuffer();
      LOG("Created attribute buffer " + attribute.name);
      gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
      gl.bufferData(gl.ARRAY_BUFFER, array, gl.STATIC_DRAW);

      buffers[attribute.name] = buffer;
    }

    var numIndices = n_elems_tuple * List.length(bufferElems);
    var indices = [];
    for (var i = 0; i < numIndices; i += 1) {
      indices.push(i);
    }
    LOG("Created index buffer");
    var indexBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint16Array(indices), gl.STATIC_DRAW);

    var bufferObject = {
      numIndices: numIndices,
      indexBuffer: indexBuffer,
      buffers: buffers
    };

    return bufferObject;

  }

  function drawGL(model) {

    var gl = model.cache.gl;

    gl.viewport(0, 0, model.w, model.h);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    LOG("Drawing");

    function drawEntity(entity) {

      var program;
      if (entity.vert.id && entity.frag.id) {
        var progid = entity.vert.id + '#' + entity.frag.id;
        program = model.cache.programs[progid];
      }

      if (!program) {

        var vshader = undefined;
        if (entity.vert.id) {
          vshader = model.cache.shaders[entity.vert.id];
        } else {
          entity.vert.id = Utils.guid();
        }

        if (!vshader) {
          vshader = do_compile(gl, entity.vert.src, gl.VERTEX_SHADER);
          model.cache.shaders[entity.vert.id] = vshader;
        }

        var fshader = undefined;
        if (entity.frag.id) {
          fshader = model.cache.shaders[entity.frag.id];
        } else {
          entity.frag.id = Utils.guid();
        }

        if (!fshader) {
          fshader = do_compile(gl, entity.frag.src, gl.FRAGMENT_SHADER);
          model.cache.shaders[entity.frag.id] = fshader;
        }

        program = do_link(gl, vshader, fshader);
        var progid = entity.vert.id + '#' + entity.frag.id;
        model.cache.programs[progid] = program;

      }

      gl.useProgram(program);

      var numUniforms = gl.getProgramParameter(program, gl.ACTIVE_UNIFORMS);
      var textureCounter = 0;
      for (var i = 0; i < numUniforms; i += 1) {
        var uniform = gl.getActiveUniform(program, i);
        var uniformLocation = gl.getUniformLocation(program, uniform.name);
        switch (uniform.type) {
          case gl.INT:
            gl.uniform1i(uniformLocation, entity.uniforms[uniform.name]);
            break;
          case gl.FLOAT:
            gl.uniform1f(uniformLocation, entity.uniforms[uniform.name]);
            break;
          case gl.FLOAT_VEC2:
            gl.uniform2fv(uniformLocation, entity.uniforms[uniform.name]);
            break;            
          case gl.FLOAT_VEC3:
            gl.uniform3fv(uniformLocation, entity.uniforms[uniform.name]);
            break;
          case gl.FLOAT_VEC4:
            gl.uniform4fv(uniformLocation, entity.uniforms[uniform.name]);
            break;
          case gl.FLOAT_MAT4:
            gl.uniformMatrix4fv(uniformLocation, false, entity.uniforms[uniform.name]);
            break;
          case gl.SAMPLER_2D:
            var texture = entity.uniforms[uniform.name];
            var tex = undefined;
            if (texture.id) {
              tex = model.cache.textures[texture.id];
            } else {
              texture.id = Utils.guid();
            }
            if (!tex) {
              tex = do_texture(gl, texture.img);
              model.cache.textures[texture.id] = tex;
            }
            var activeName = 'TEXTURE' + textureCounter;
            gl.activeTexture(gl[activeName]);
            gl.bindTexture(gl.TEXTURE_2D,tex);
            gl.uniform1i(uniformLocation, textureCounter);
            textureCounter += 1;
            break;
          default:
            LOG("Unsupported uniform type: " + uniform.type);
            break;
        }
      }

      var buffer = model.cache.buffers[entity.buffer.guid];
      if (!buffer) {
        buffer = do_bind(gl, program, entity.buffer, gl[entity.primitive]);
        model.cache.buffers[entity.buffer.guid] = buffer;
      }

      var numIndices = buffer.numIndices;
      var indexBuffer = buffer.indexBuffer;
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);

      var numAttributes = gl.getProgramParameter(program, gl.ACTIVE_ATTRIBUTES);
      for (var i = 0; i < numAttributes; i += 1) {
        var attribute = gl.getActiveAttrib(program, i);
        var attribLocation = gl.getAttribLocation(program, attribute.name);
        gl.enableVertexAttribArray(attribLocation);
        var attributeBuffer = buffer.buffers[attribute.name];

        switch (attribute.type) {
          case gl.FLOAT_VEC2:
            gl.bindBuffer(gl.ARRAY_BUFFER, attributeBuffer);
            gl.vertexAttribPointer(attribLocation, 2, gl.FLOAT, false, 0, 0);
            break;
          case gl.FLOAT_VEC3:
            gl.bindBuffer(gl.ARRAY_BUFFER, attributeBuffer);
            gl.vertexAttribPointer(attribLocation, 3, gl.FLOAT, false, 0, 0);
            break;
          case gl.FLOAT_VEC4:
            gl.bindBuffer(gl.ARRAY_BUFFER, attributeBuffer);
            gl.vertexAttribPointer(attribLocation, 4, gl.FLOAT, false, 0, 0);
            break;
          default:
            LOG("Unsupported attribute type: " + attribute.type);
            break;
        }
      }

      gl.drawElements(gl[entity.primitive], numIndices, gl.UNSIGNED_SHORT, 0);

    }

    A2(List.map, drawEntity, model.models);

  }

  function webgl(dimensions, models) {

    var w = dimensions._0;
    var h = dimensions._1;

    function render(model) {

      var div = createNode('div');
      div.style.overflow = 'hidden';
      var canvas = createNode('canvas');
      var gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');

      if (gl) {
        gl.enable(gl.DEPTH_TEST);
      } else {
        div.innerHTML =
          '<div style="display: table-cell; text-align: center; width: ' + w + 'px; height: ' + h +
          'px; vertical-align: middle;"><a href="http://get.webgl.org/">Enable WebGL</a> to see this content!</div>';
      }

      model.cache.gl = gl;
      model.cache.canvas = canvas;
      model.cache.shaders = [];
      model.cache.programs = {};
      model.cache.buffers = [];
      model.cache.textures = [];

      update(div, model, model);

      return div;

    }

    function update(div, oldModel, newModel) {

      newModel.cache = oldModel.cache;

      var canvas = newModel.cache.canvas;

      canvas.style.width = oldModel.w + 'px';
      canvas.style.height = oldModel.h + 'px';
      canvas.style.display = "block";
      canvas.style.position = "absolute";
      canvas.width = oldModel.w;
      canvas.height = oldModel.h;

      if (newModel.cache.gl) {
        drawGL(newModel);
      } else {
        div.firstChild.width = newModel.w + 'px';
        div.firstChild.height = newModel.h + 'px';
      }

      div.appendChild(canvas);

      return div;
    }

    var elem = {
      ctor: 'Custom',
      type: 'WebGL',
      render: render,
      update: update,
      model: {
        models: models,
        cache: {},
        w: w,
        h: h
      }
    };

    return A3(newElement, w, h, elem);

  }

  return elm.Native.WebGL.values = {
    unsafeCoerceGLSL: unsafeCoerceGLSL,
    loadTexture: loadTexture,
    trianglesEntity: F4(trianglesEntity),
    linesEntity: F4(linesEntity),
    pointsEntity: F4(pointsEntity),
    webgl: F2(webgl),
  };

};
