//
//  OpenGLTextureBlitter.swift
//  SceneKitRenderToTexture
//
//  Copyright © 2016 NybbleGames. All rights reserved.
//

import GLKit

class OpenGLTextureBlitter {

    private struct Vertex {
        var position:(GLfloat, GLfloat, GLfloat)
        var texCoord:(GLfloat, GLfloat)
    }

    private struct OpenGLState {
        let program:GLuint
        let arrayBuffer:GLuint
        let framebuffer:GLuint
        let texture:GLuint
        let enableDepthTest:Bool

        static func store() -> OpenGLState {
            var program:GLint = 0
            var arrayBuffer:GLint = 0
            var framebuffer:GLint = 0
            var texture:GLint = 0
            var depthTestEnabled:GLboolean = GLboolean(GL_FALSE)

            glGetIntegerv(GLenum(GL_CURRENT_PROGRAM), &program)
            glGetIntegerv(GLenum(GL_ARRAY_BUFFER_BINDING), &arrayBuffer)
            glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &framebuffer)
            glGetIntegerv(GLenum(GL_TEXTURE_BINDING_2D), &texture)
            depthTestEnabled = glIsEnabled(GLenum(GL_DEPTH_TEST))

            return OpenGLState(
                program: GLuint(program),
                arrayBuffer: GLuint(arrayBuffer),
                framebuffer: GLuint(framebuffer),
                texture: GLuint(texture),
                enableDepthTest: depthTestEnabled == GLboolean(GL_TRUE) ? true : false)
        }

        func restore() {
            glUseProgram(self.program)
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), self.arrayBuffer)
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.framebuffer)
            glBindTexture(GLenum(GL_TEXTURE_2D), self.texture)

            if self.enableDepthTest {
                glEnable(GLenum(GL_DEPTH_TEST))
            }
        }
    }

    private struct Constants {
        static let NumVertexStructPosFloats = 3
        static let NumVertexStructTexCoordFloats = 2

        static let VertexStructPosOffset = 0
        static let VertexStructTexCoordOffset = 3 * sizeof(GLfloat)

        static let PositionAttirbute = "position"
        static let TextureCoordsAttribute = "textureCoordinates"

        static let MVPMatrixUniform = "modelViewProjectionMatrix"
        static let TextureUniform = "texture"
        static let TextureTransformUniform = "textureTransformMatrix"

        static let TexCoordFragmentOut = "vTextureCoord"

        static let VertexShader =
            "uniform mat4 \(MVPMatrixUniform);\n" +
                "uniform mat4 \(TextureTransformUniform);\n" +
                "\n" +
                "attribute vec3 \(PositionAttirbute);\n" +
                "attribute vec2 \(TextureCoordsAttribute);\n" +
                "\n" +
                "varying vec2 \(TexCoordFragmentOut);\n" +
                "void main() {\n" +
                "    gl_Position = \(MVPMatrixUniform) * vec4(\(PositionAttirbute), 1.0);\n" +
                "    vTextureCoord = (\(TextureTransformUniform) * vec4(\(TextureCoordsAttribute), 0.0, 1.0)).xy;\n" +
        "}\n"

        static let SimpleFragmentShader =
            "precision mediump float;\n" +
                "\n" +
                "varying vec2 \(TexCoordFragmentOut);\n" +
                "\n" +
                "uniform sampler2D \(TextureUniform);\n" +
                "\n" +
                "void main() {\n" +
                "    gl_FragColor = texture2D(\(TextureUniform), \(TexCoordFragmentOut));\n" +
        "}\n"

        static let vertexArray:[Vertex] = [
            Vertex(position: (-1.0, -1.0, 0.0), texCoord: (0.0, 0.0)),
            Vertex(position: (1.0, -1.0, 0.0), texCoord: (1.0, 0.0)),
            Vertex(position: (-1.0,  1.0, 0.0), texCoord: (0.0, 1.0)),
            Vertex(position: (1.0,  1.0, 0.0), texCoord: (1.0, 1.0))
        ]
    }

    private var eaglContext:EAGLContext
    private var objectsConstructed:Bool
    private var quadBuffer:GLuint?
    private var shader:GLProgram?

    init(_ context:EAGLContext) {
        self.eaglContext = context

        self.objectsConstructed = false
    }

    deinit {
        // TODO*: Is there a way to have this run in particular
        // queue to make sure the context isn't current in more
        // than one
        let prevContext = EAGLContext.currentContext()
        EAGLContext.setCurrentContext(self.eaglContext)

        if var buffer = self.quadBuffer where buffer > 0 {
            glDeleteBuffers(1, &buffer)
        }

        EAGLContext.setCurrentContext(prevContext)
    }

    // MARK: - Public Functions

    func blitTexture(
        textureName:GLuint,
        toFramebuffer framebuffer:GLuint)
    {
        self.blitTexture(textureName, toFramebuffer: framebuffer, withInvertedY: false)
    }

    func blitTexture(
        textureName:GLuint,
        toFramebuffer framebuffer:GLuint,
        withInvertedY inverted:Bool)
    {
        if !self.objectsConstructed {
            self.constructObjects()
        }

        guard let program = self.shader else {
            // Unexpected, some error when setting these up
            return
        }

        let state:OpenGLState = self.setStateForDrawing(
            inverted,
            texName: textureName,
            framebuffer: framebuffer,
            program: program)

        glClear(GLenum(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT));
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4);

        state.restore()
    }

    private func constructObjects() {
        let prevContext = EAGLContext.currentContext()
        EAGLContext.setCurrentContext(self.eaglContext)

        defer {
            EAGLContext.setCurrentContext(prevContext)
            self.objectsConstructed = true
        }

        // Just set an arbitary value here so that the optional is Some<Int>
        var newBuffer:GLuint = 0
        glGenBuffers(1, &newBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), newBuffer)
        glBufferData(
            GLenum(GL_ARRAY_BUFFER),
            GLsizeiptr(Constants.vertexArray.count * sizeof(Vertex)),
            Constants.vertexArray,
            GLenum(GL_STATIC_DRAW))

        guard let shader = GLProgram(
            vertexShader: Constants.VertexShader,
            fragmentShader: Constants.SimpleFragmentShader) else { return }

        self.shader = shader
        self.quadBuffer = newBuffer
    }

    private func setStateForDrawing(inverted:Bool, texName:GLuint, framebuffer:GLuint, program:GLProgram) -> OpenGLState {
        let savedState:OpenGLState = OpenGLState.store()

        guard let buffer = self.quadBuffer else {
            return savedState
        }

        // Grab state
        glDisable(GLenum(GL_DEPTH_TEST))

        program.use()

        // Supply the texture unit uniform
        if let uniformLoc = program.getUniformLocation(Constants.TextureUniform) {
            glUniform1i(uniformLoc, 0) // texture unit 0
        }

        // Supply MVP matrix uniform
        if let uniformLoc = program.getUniformLocation(Constants.MVPMatrixUniform) {
            var mvpMatrix = GLKMatrix4Identity
            let pointer = withUnsafeMutablePointer(&mvpMatrix) { UnsafePointer<GLfloat>($0) }
            glUniformMatrix4fv(
                uniformLoc,
                1,
                GLboolean(GL_FALSE),
                pointer)
        }

        // Supply texture coordinate transform
        if let uniformLoc = program.getUniformLocation(Constants.TextureTransformUniform) {
            var texMatrix:GLKMatrix4

            if !inverted {
                texMatrix = GLKMatrix4Identity
            } else {
                texMatrix = GLKMatrix4MakeWithColumns(
                    GLKVector4Make(1.0,  0.0, 0.0, 0.0),
                    GLKVector4Make(0.0, -1.0, 0.0, 0.0),
                    GLKVector4Make(0.0,  0.0, 1.0, 0.0),
                    GLKVector4Make(0.0,  1.0, 0.0, 1.0))
            }

            let pointer = withUnsafeMutablePointer(&texMatrix) { UnsafePointer<GLfloat>($0) }
            glUniformMatrix4fv(
                uniformLoc,
                1,
                GLboolean(GL_FALSE),
                pointer)
        }

        // Bind buffer and set attribute offsets, etc. for VBO.
        // TODO*: Use VAOs to store all of this once and reuse
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)

        if let attrLoc = program.getAttributeLocation(Constants.PositionAttirbute) {
            let ptr:UnsafePointer<Void> = nil + Constants.VertexStructPosOffset
            glEnableVertexAttribArray(attrLoc)
            glVertexAttribPointer(
                attrLoc,
                GLint(Constants.NumVertexStructPosFloats),
                GLenum(GL_FLOAT),
                GLboolean(0),
                GLsizei(sizeof(Vertex)),
                ptr)
        }

        if let attrLoc = program.getAttributeLocation(Constants.TextureCoordsAttribute) {
            let ptr:UnsafePointer<Void> = nil + Constants.VertexStructTexCoordOffset
            glEnableVertexAttribArray(attrLoc)
            glVertexAttribPointer(
                attrLoc,
                GLint(Constants.NumVertexStructTexCoordFloats),
                GLenum(GL_FLOAT),
                GLboolean(0),
                GLsizei(sizeof(Vertex)),
                ptr)
        }
        
        // Inform OpenGL of where to render and which texture to blit
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        glBindTexture(GLenum(GL_TEXTURE_2D), texName)
        
        return savedState
    }
}
