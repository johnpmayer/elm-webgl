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

  function loadTexture(source, filter) {
    return Task.asyncFunction(function(callback) {
      var img = new Image();
      img.onload = function() {
        return callback(Task.succeed({ctor:'Texture', img:img, filter:filter}));
      };
      img.onerror = function(e) {
        return callback(Task.fail({ ctor: 'Error' }));
      };
      img.src = source;
    });
  }

  function textureSize(texture) {

    return Tuple2(texture.img.width, texture.img.height);

  }
  
  function render(vert, frag, buffer, uniforms, functionCalls) {

    if (!buffer.guid) {
      buffer.guid = Utils.guid();
    }

    return {
      vert: vert,
      frag: frag,
      buffer: buffer,
      uniforms: uniforms,
      functionCalls : functionCalls
    };

  }

  function do_texture (gl, texture) {

    var tex = gl.createTexture();
    LOG("Created texture");
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, texture.img);
    switch (texture.filter.ctor) {
      case 'Linear':
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        break;
      case 'Nearest':
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        break;
    };
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

  function get_render_info(gl, render_type) {
	switch(render_type) {
		case 'Triangle': return { mode: gl.TRIANGLES, elemSize: 3 }; 
		case 'LineStrip' : return { mode: gl.LINE_STRIP, elemSize: 1 };
		case 'LineLoop' : return { mode: gl.LINE_LOOP, elemSize: 1 };
		case 'Points' : return { mode: gl.POINTS, elemSize: 1 };
		case 'Lines': return { mode: gl.LINES, elemSize: 2 }; 
		case 'TriangleStrip': return { mode: gl.TRIANGLE_STRIP, elemSize: 1 }; 
		case 'TriangleFan': return { mode: gl.TRIANGLE_FAN, elemSize: 1 }; 
	}
  }; 

  function get_attribute_info(gl, type) {
		switch(type) {
			case gl.FLOAT:      return { size: 1, type: Float32Array, baseType: gl.FLOAT };
			case gl.FLOAT_VEC2: return { size: 2, type: Float32Array, baseType: gl.FLOAT };
			case gl.FLOAT_VEC3: return { size: 3, type: Float32Array, baseType: gl.FLOAT };
			case gl.FLOAT_VEC4: return { size: 4, type: Float32Array, baseType: gl.FLOAT };			
			case gl.INT: 		return { size: 1, type: Int32Array, baseType: gl.INT };
			case gl.INT_VEC2: 	return { size: 2, type: Int32Array, baseType: gl.INT };
			case gl.INT_VEC3: 	return { size: 3, type: Int32Array, baseType: gl.INT };
			case gl.INT_VEC4: 	return { size: 4, type: Int32Array, baseType: gl.INT };			
		}
	  };
      
  /**
        Form the buffer for a given attribute. 
        
        @param gl gl context
        @param attribute the attribute to bind to. We use its name to grab the record by name and also to know
                how many elements we need to grab.
        @param bufferElems The list coming in from elm. 
        @param elem_length The length of the number of vertices that complete one 'thing' based on the drawing mode. 
            ie, 2 for Lines, 3 for Triangles, etc. 
  */
  function do_bind_attribute (gl, attribute, bufferElems, elem_length) {      
    var idxKeys = []; 
    for(var i = 0;i < elem_length;i++) idxKeys.push('_'+i); 

    function dataFill(data, cnt, fillOffset, elem, key) {						
        if(elem_length == 1)
            for(var i = 0;i < cnt;i++)
                data[fillOffset++] = cnt === 1 ? elem[key] : elem[key][i];			
        else
            idxKeys.forEach( function(idx) {
                for(var i = 0;i < cnt;i++) 
                    data[fillOffset++] = (cnt === 1 ? elem[idx][key] : elem[idx][key][i]);						
            }); 		
    };

    var attributeInfo = get_attribute_info(gl, attribute.type); 

    if(attributeInfo === undefined) {
        throw error("No info available for: " + attribute.type); 
    }

    var data_idx = 0; 
    var array = new attributeInfo.type( List.length(bufferElems) * attributeInfo.size * elem_length);
      
    A2(List.map, function(elem) {
        dataFill(array, attributeInfo.size, data_idx, elem, attribute.name); 
        data_idx += attributeInfo.size * elem_length;
    }, bufferElems);

    var buffer = gl.createBuffer();
    LOG("Created attribute buffer " + attribute.name);
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, array, gl.STATIC_DRAW);
    return buffer; 
  };
  
  /**
    This sets up the binding cacheing buffers. 
    
    We don't actually bind any buffers now except for the indices buffer, which we fill with 0..n. The problem
    with filling the buffers here is that it is possible to have a buffer shared between two webgl shaders; which
    could have different active attributes. If we bind it here against a particular program, we might not bind 
    them all. That final bind is now done right before drawing. 
    
    @param gl gl context
    @param bufferElems The list coming in from elm. 
    @param elem_length The length of the number of vertices that complete one 'thing' based on the drawing mode. 
            ie, 2 for Lines, 3 for Triangles, etc. 
  */
  function do_bind_setup (gl, bufferElems, elem_length) {
	var buffers = {};
    
    var numIndices = elem_length * List.length(bufferElems);
    var indices = new Uint16Array(numIndices);
    for (var i = 0; i < numIndices; i += 1) {
      indices[i] = i; 
    }
    LOG("Created index buffer");
    var indexBuffer = gl.createBuffer();
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);

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

    function drawEntity(render) {
      if(List.length(render.buffer._0) === 0)
          return;
      
      var program;
      if (render.vert.id && render.frag.id) {
        var progid = render.vert.id + '#' + render.frag.id;
        program = model.cache.programs[progid];
      }

      if (!program) {

        var vshader = undefined;
        if (render.vert.id) {
          vshader = model.cache.shaders[render.vert.id];
        } else {
          render.vert.id = Utils.guid();
        }

        if (!vshader) {
          vshader = do_compile(gl, render.vert.src, gl.VERTEX_SHADER);
          model.cache.shaders[render.vert.id] = vshader;
        }

        var fshader = undefined;
        if (render.frag.id) {
          fshader = model.cache.shaders[render.frag.id];
        } else {
          render.frag.id = Utils.guid();
        }

        if (!fshader) {
          fshader = do_compile(gl, render.frag.src, gl.FRAGMENT_SHADER);
          model.cache.shaders[render.frag.id] = fshader;
        }

        program = do_link(gl, vshader, fshader);
        var progid = render.vert.id + '#' + render.frag.id;
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
            gl.uniform1i(uniformLocation, render.uniforms[uniform.name]);
            break;
          case gl.FLOAT:
            gl.uniform1f(uniformLocation, render.uniforms[uniform.name]);
            break;
          case gl.FLOAT_VEC2:
            gl.uniform2fv(uniformLocation, render.uniforms[uniform.name]);
            break;
          case gl.FLOAT_VEC3:
            gl.uniform3fv(uniformLocation, render.uniforms[uniform.name]);
            break;
          case gl.FLOAT_VEC4:
            gl.uniform4fv(uniformLocation, render.uniforms[uniform.name]);
            break;
          case gl.FLOAT_MAT4:
            gl.uniformMatrix4fv(uniformLocation, false, render.uniforms[uniform.name]);
            break;
          case gl.SAMPLER_2D:
            var texture = render.uniforms[uniform.name];
            var tex = undefined;
            if (texture.id) {
              tex = model.cache.textures[texture.id];
            } else {
              texture.id = Utils.guid();
            }
            if (!tex) {
              tex = do_texture(gl, texture);
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
	  var renderType = get_render_info(gl, render.buffer.ctor); 
      var buffer = model.cache.buffers[render.buffer.guid];
      
      if (!buffer) {
        buffer = do_bind_setup(gl, render.buffer._0, renderType.elemSize);
        model.cache.buffers[render.buffer.guid] = buffer;
      }

      var numIndices = buffer.numIndices;
      var indexBuffer = buffer.indexBuffer;
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);

      var numAttributes = gl.getProgramParameter(program, gl.ACTIVE_ATTRIBUTES);
        
      for (var i = 0; i < numAttributes; i += 1) {
        var attribute = gl.getActiveAttrib(program, i);
        
        var attribLocation = gl.getAttribLocation(program, attribute.name);
        gl.enableVertexAttribArray(attribLocation);
                
        if(buffer.buffers[attribute.name] === undefined) {                 
            buffer.buffers[attribute.name] = do_bind_attribute (gl, attribute, render.buffer._0, renderType.elemSize);
        }
        var attributeBuffer = buffer.buffers[attribute.name];         
        var attributeInfo = get_attribute_info(gl, attribute.type); 

        A2(List.map, function(functionCall){
          functionCall(gl);
        }, render.functionCalls);

        gl.bindBuffer(gl.ARRAY_BUFFER, attributeBuffer);
        gl.vertexAttribPointer(attribLocation, attributeInfo.size, attributeInfo.baseType, false, 0, 0);
      }
      gl.drawElements(renderType.mode, numIndices, gl.UNSIGNED_SHORT, 0);

    }

    A2(List.map, drawEntity, model.models);

  }

  function enable(capability) {
    return function(gl) { gl.enable(gl[capability]); };
  }

  function disable(capability) {
    return function(gl) { gl.disable(gl[capability]); };
  }

  function blendColor(r, g, b, a) {
    return function(gl) { gl.blendColor(r, g, b, a); };
  }

  function blendEquation(mode) {
    return function(gl) { gl.blendEquation(gl[mode]); };
  }

  function blendEquationSeparate(modeRGB, modeAlpha) {
    return function(gl) {
      gl.blendEquationSeparate(gl[modeRGB], gl[modeAlpha]);
    };
  }

  function blendFunc(src, dst) {
    return function(gl) { gl.blendFunc(gl[src], gl[dst]); };
  }

  function depthFunc(mode) {
    return function(gl) { gl.depthFunc(gl[mode]); };
  }

  function sampleCoverage(value, invert) {
    return function(gl) {
      gl.sampleCoverage(value, invert);
    };
  }

  function stencilFunc(func, ref, mask) {
    return function(gl) {
      gl.stencilFunc(gl[func], ref, mask);
    };
  }

  function stencilFuncSeparate(face, func, ref, mask) {
    return function(gl) {
      gl.stencilFuncSeparate(gl[face], gl[func], ref, mask);
    };
  }

  function stencilOperation(fail, zfail, zpass) {
    return function(gl) {
      gl.stencilOperation(gl[fail], gl[zfail], gl[zpass]);
    }
  }

  function stencilOperationSeparate(face, fail, zfail, zpass) {
    return function(gl) {
      gl.stencilOperationSeparate(gl[face], gl[fail], gl[zfail], gl[zpass]);
    }
  }

  function webgl(dimensions, models, functionCalls) {

    var w = dimensions._0;
    var h = dimensions._1;

    function render(model) {

      var div = createNode('div');
      div.style.overflow = 'hidden';
      var canvas = createNode('canvas');
      var gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');

      if (gl) {
        A2(List.map, function(functionCall){
          functionCall(gl);
        }, functionCalls);
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
    unsafeCoerceGLSL:unsafeCoerceGLSL,
    textureSize:textureSize,
    loadTexture:F2(loadTexture),
    render:F5(render),
    webgl:F3(webgl),
    enable:enable,
    disable:disable,
    blendColor:F4(blendColor),
    blendEquation:blendEquation,
    blendEquationSeparate:F2(blendEquationSeparate),
    blendFunc:F2(blendFunc),
    depthFunc:depthFunc,
    sampleCoverage:F2(sampleCoverage),
    stencilFunc:F3(stencilFunc),
    stencilFuncSeparate:F4(stencilFuncSeparate),
    stencilOperation:F3(stencilOperation),
    stencilOperationSeparate:F4(stencilOperationSeparate)
  };

};
