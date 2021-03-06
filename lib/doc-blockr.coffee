DocBlockrView = require './doc-blockr-view'
_ = require 'underscore-plus'
path = require 'path'
async = require 'async'
CSON = require 'season'
{File} = require 'pathwatcher'
fs = require 'fs-plus'

###*
 * My todo's:
 * SPECS!
 * Formating for blocks and all the behavior that comes with that.
 * Triggers for `{` i.e. {@code blah}.
 * Activate for newly opened tabs.
 * Autocomplete box when typing insert that text into the DOM.
 * Autocomplete box if no match found exit.
###
module.exports =
  autocompleteViews: []
  editorSubscription: null
  languagesLoaded: false
  docBlockrView: null
  snippetsByPrefix: {}
  languageFileRegex: /language-\w+.cson/

  activate: (state) ->
    atom.project.registerOpener (uri) =>
      if uri is 'atom://.atom/snippets'
        atom.workspaceView.open(@getUserSnippetsPath())

    @findAndLoadAllLanguages()

    @editorSubscription = atom.workspaceView.eachEditorView (editor) =>
      if editor.attached and not editor.mini
        autocompleteView = new DocBlockrView(editor, @snippetsByPrefix, @languagesLoaded)
        editor.on 'editor:will-be-removed', =>
          autocompleteView.remove() unless autocompleteView.hasParent()
          _.remove(@autocompleteViews, autocompleteView)
        @autocompleteViews.push(autocompleteView)

  getUserSnippetsPath: ->
    userSnippetsPath = CSON.resolve(path.join(atom.getConfigDirPath(), 'snippets'))
    userSnippetsPath ? path.join(atom.getConfigDirPath(), 'snippets.cson')

  findAndLoadAllLanguages: ->
    pkg = atom.packages.getLoadedPackage("doc-blockr")

    files = fs.listSync((path.join(pkg.path, 'snippets')))
    @loadAllLanguages @filterLanguageFiles files

  filterLanguageFiles: (files) ->
    filtered = []
    for path in files
      file = new File(path)
      if @languageFileRegex.test(file.getBaseName()) then filtered.push(path)

    (file for file in filtered when CSON.resolve(file))

  loadAllLanguages: (snippetsDirPaths) ->
    async.eachSeries snippetsDirPaths, @loadSnippetFiles.bind(this), @doneLoading.bind(this)

  loadSnippetFiles: (filePath, onComplete) ->
    unless CSON.isObjectPath(filePath)
      console.warn "Error reading snippets from: '#{filePath}'."
      return

    CSON.readFile filePath, (error, object={}) =>
      if error?
        console.warn "Error reading snippets file '#{filePath}': #{error.stack ? error}"
      else
        @addSnippetPrefixes(filePath, object, onComplete)

  addSnippetPrefixes: (filePath, snippetsBySelector, onComplete) ->
    for selector, snippetsByName of snippetsBySelector
      for name, attributes of snippetsByName
        lang = new File(filePath).getBaseName().split(".")[0].replace('language-', '')
        @snippetsByPrefix[lang] = [] unless @snippetsByPrefix[lang]
        @snippetsByPrefix[lang].push attributes.prefix
    onComplete()

  doneLoading: ->
    # I set this here for any new tabs that might open through my
    # editorSubscription. And also I emit the event for any open editors that
    # have already been initialized.
    @languagesLoaded = true
    atom.packages.emit 'doc-blockr:loaded'

  deactivate: ->
    @editorSubscription?.off()
    @editorSubscription = null
    @autocompleteViews.forEach (autocompleteView) -> autocompleteView.remove()
    @autocompleteViews = []
