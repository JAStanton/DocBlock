{View} = require 'atom'
helpers = require './helper'

AutocompleteView = require './autocomplete-view'

module.exports =
class DocBlockrView extends AutocompleteView
  languagesLoaded: false
  attachWhenReady: false

  initialize: (@editor, @snippets, @languagesLoaded) ->
    atom.packages.on "doc-blockr:loaded", => @onComplete()
    atom.workspaceView.command "doc-blockr:toggle", => @toggle()
    super(@editor)

  onComplete: ->
    @languagesLoaded = true
    @attach() if @attachWhenReady

  getCommentRegex: ->
    switch @getLanguage()
      when "js","java","actionscript","groovy" then /\*/
      when "coffee" then /[#\*]/

  isAfterCommentCharacter: ->
    cursor = @editor.getCursor()
    startPoint = cursor.getBeginningOfCurrentWordBufferPosition(wordRegex: @getCommentRegex())
    text = @editor.getTextInRange([startPoint, cursor.getBufferPosition()])
    text?.replace(/\s/g, '').length is 1

  isInsideCommentBlock: ->
    scopes = @editor.getCursor().getScopes()
    inBlock = false
    i = 0
    while i < scopes.length
      inBlock = true if scopes[i].indexOf("comment.block") != -1
      i++
    inBlock

  getLanguage: ->
    scopes = @editor.getCursor().getScopes()
    for scope in scopes
      return scope.replace('source.', '') if scope.indexOf('source') is 0

  buildWordList: ->
    @wordList = @snippets[@getLanguage()]

  confirmed: ->
    super
    helpers.keydown('\t')

  toggle: ->
    return unless @editorView.isVisible()
    unless @isInsideCommentBlock() and @isAfterCommentCharacter()
      @editor.insertText("@")
      return
    # Todo: load the UI with "loading..." as a disabled seleciton.
    if @languagesLoaded then @attach() else @attachWhenReady = true
