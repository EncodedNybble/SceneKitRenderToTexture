//
//  RenderToTextureDelegate.swift
//  SceneKitRenderToTexture
//
//  Copyright © 2016 NybbleGames. All rights reserved.
//

import Foundation
import SceneKit

class RenderToTextureDelegate : NSObject, SCNSceneRendererDelegate {

    // MARK: - Types
    private struct FrameRenderInfo {
        let previousFBO:GLuint
        let previousViewport:[GLint]
    }

    // MARK: - Private Properties
    private var screenWidthPixels:GLsizei
    private var screenHeightPixels:GLsizei

    private var offscreenFramebuffer:GLuint?
    private var offscreenTexture:GLuint?

    private var textureBlitter:OpenGLTextureBlitter?

    private var currentFrameInfo:FrameRenderInfo?

    init(screenSize:CGSize, glContext:EAGLContext)
    {
        self.screenWidthPixels = GLsizei(screenSize.width)
        self.screenHeightPixels = GLsizei(screenSize.height)

        self.textureBlitter = OpenGLTextureBlitter(glContext)

        super.init()
    }

    // MARK: - SCNSceneRendererDelegate

    func renderer(renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: NSTimeInterval) {
        guard self.textureBlitter != nil else {
            return
        }

        // Create FBO to render to if it doesn't already exist
        if self.offscreenFramebuffer == nil {
            self.createScreenSizedTextureBackedFramebuffer()
        }

        // Save off the frame buffer that the SCNSceneRenderer is rendering to and substitute our own
        var fbo:GLint = 0
        var viewport:[GLint] = [0, 0, 0, 0]
        glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &fbo)
        glGetIntegerv(GLenum(GL_VIEWPORT), &viewport)

        // Bind the frame buffer from the render texture so that the scene is rendered to
        // a texture instead of the default framebuffer that the SCNSceneRenderer will use
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), self.offscreenFramebuffer!)
        glViewport(0, 0, self.screenWidthPixels, self.screenHeightPixels)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))


        self.currentFrameInfo = FrameRenderInfo(
            previousFBO: GLuint(fbo),
            previousViewport: viewport)
    }

    func renderer(renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: NSTimeInterval) {
        guard let frameInfo = self.currentFrameInfo, screenTexture = self.offscreenTexture else {
            return
        }

        // Blit from the offscreen texture to screen
        self.copyScreenTextureToPixelBufferAndScreen(
            screenTexture: screenTexture,
            screenFBO: frameInfo.previousFBO)

        // Rebind previous fbo
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameInfo.previousFBO)

        // Rebind previous view port
        glViewport(
            frameInfo.previousViewport[0],
            frameInfo.previousViewport[1],
            frameInfo.previousViewport[2],
            frameInfo.previousViewport[3])

        self.currentFrameInfo = nil
    }

    private func createScreenSizedTextureBackedFramebuffer() {
        // Create framebuffer object, grab the previously bound one too
        var fbo:GLuint = 0
        var texture:GLuint = 0
        var depthAttachment:GLint = 0
        var prevFbo:GLint = 0
        var prevTexture:GLint = 0

        glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &prevFbo)
        glGetIntegerv(GLenum(GL_TEXTURE_BINDING_2D), &prevTexture)
        glGetFramebufferAttachmentParameteriv(
            GLenum(GL_FRAMEBUFFER),
            GLenum(GL_DEPTH_ATTACHMENT),
            GLenum(GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME),
            &depthAttachment)

        glGenFramebuffers(1, &fbo)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo)

        // Create an empty texture of appropriate size
        glGenTextures(1, &texture)
        glBindTexture(GLenum(GL_TEXTURE_2D), texture);
        glTexImage2D(
            GLenum(GL_TEXTURE_2D),
            0,
            GL_RGBA,
            self.screenWidthPixels,
            self.screenHeightPixels,
            0,
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            nil);

        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE);
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE);

        // Attach color and depth attachments
        glFramebufferTexture2D(
            GLenum(GL_FRAMEBUFFER),
            GLenum(GL_COLOR_ATTACHMENT0),
            GLenum(GL_TEXTURE_2D),
            texture,
            0);

        // Use same depth buffer
        glFramebufferRenderbuffer(
            GLenum(GL_FRAMEBUFFER),
            GLenum(GL_DEPTH_ATTACHMENT),
            GLenum(GL_RENDERBUFFER),
            GLuint(depthAttachment))

        glBindTexture(GLenum(GL_TEXTURE_2D), GLuint(prevTexture))
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), GLuint(prevFbo))

        self.offscreenFramebuffer = fbo
        self.offscreenTexture = texture
    }

    private func copyScreenTextureToPixelBufferAndScreen(
        screenTexture texture:GLuint,
        screenFBO:GLuint)
    {
        guard let blitter = self.textureBlitter else {
            return
        }

        glViewport(0, 0, self.screenWidthPixels, self.screenHeightPixels)
        blitter.blitTexture(
            texture,
            toFramebuffer: screenFBO)
    }
}