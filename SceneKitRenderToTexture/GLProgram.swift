//
//  GLProgram.swift
//  SceneKitRenderToTexture
//
//  Copyright © 2016 NybbleGames. All rights reserved.
//

import GLKit

class GLProgram  {

    private(set) var program:GLuint = GLuint()

    private var attributeLocationMap = [String : GLuint]()
    private var uniformLocationMap = [String : GLint]()

    init?(vertexShader:String, fragmentShader:String) {
        var vertShader:GLuint = GLuint()
        var fragShader:GLuint = GLuint()

        self.program = glCreateProgram()

        if self.program == 0 {
            return nil
        }

        var success = self.compileShader(
            &vertShader,
            GLenum(GL_VERTEX_SHADER),
            vertexShader)

        if !success {
            NSLog("Failed to compile vertex shader")
        }

        if ( success ) {
            success = self.compileShader(
                &fragShader,
                GLenum(GL_FRAGMENT_SHADER),
                fragmentShader)

            if success {
                glAttachShader(program, vertShader);
                glAttachShader(program, fragShader);

                success = self.link(vertexShader: vertShader, fragmentShader: fragShader)

                if success {
                    self.parseAttributeAndUniformLocations()
                }
            } else {
                NSLog("Failed to compile fragment shader")
            }
        }

        if vertShader > 0 {
            glDeleteShader(vertShader)
        }

        if fragShader > 0 {
            glDeleteShader(fragShader)
        }

        if !success {
            glDeleteProgram(self.program);
            self.program = 0

            return nil
        }
    }

    deinit {
        if self.program > 0 {
            glDeleteProgram(self.program);
            self.program = 0
        }
    }

    func getAttributeLocation(attributeName:String) -> GLuint? {
        return self.attributeLocationMap[attributeName]
    }

    func getUniformLocation(uniformName:String) -> GLint? {
        return self.uniformLocationMap[uniformName]
    }

    func use() {
        if self.program > 0 {
            glUseProgram(self.program)
        }
    }

    private func link(vertexShader vertShader:GLuint, fragmentShader fragShader:GLuint) -> Bool {
        var status:GLint = 0

        glLinkProgram(self.program);
        glValidateProgram(self.program);

        glGetProgramiv(self.program, GLenum(GL_LINK_STATUS), &status);

        return status == GL_TRUE
    }

    private func parseAttributeAndUniformLocations() {
        let bufSize:GLsizei = 256 // Maximum name length
        var name:[GLchar] = [GLchar](count:Int(bufSize), repeatedValue: 0)
        var nameLength:GLsizei = 0
        var type:GLenum = 0 // don't really care about this one
        var size:GLsizei = 0 // also don't care about this one

        // Attributes first
        var numAttributes:GLint = 0
        glGetProgramiv(self.program, GLenum(GL_ACTIVE_ATTRIBUTES), &numAttributes)

        for index:GLint in GLint(0)..<numAttributes {
            glGetActiveAttrib(
                self.program,
                GLuint(index),
                bufSize,
                &nameLength,
                &size,
                &type,
                &name)

            let nameString = NSString(
                bytes: name,
                length: Int(nameLength),
                encoding: NSUTF8StringEncoding) as! String

            self.attributeLocationMap[nameString] = GLuint(glGetAttribLocation(self.program, nameString))
        }

        var numUniforms:GLint = 0
        glGetProgramiv(self.program, GLenum(GL_ACTIVE_UNIFORMS), &numUniforms)
        for index:GLint in GLint(0)..<numUniforms {
            glGetActiveUniform(
                self.program,
                GLuint(index),
                bufSize,
                &nameLength,
                &size,
                &type,
                &name)

            let nameString = NSString(
                bytes: name,
                length: Int(nameLength),
                encoding: NSUTF8StringEncoding) as! String

            self.uniformLocationMap[nameString] = glGetUniformLocation(self.program, nameString)
        }
    }

    private func compileShader(inout shader:GLuint, _ type:GLenum, _ source:String) -> Bool {
        var status:GLint = 0

        shader = glCreateShader(type);
        var cStringSource = (source as NSString).UTF8String
        glShaderSource(shader, GLsizei(1), &cStringSource, nil);
        glCompileShader(shader);
        
        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status);
        return status == GL_TRUE;
    }
}
