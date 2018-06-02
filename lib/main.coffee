WordcountView = require './wordcount-view'
_ = require 'lodash'

view = null
tile = null

module.exports =

  config:
    alwaysOn:
      title: 'Always on'
      description: 'Show word count for all files, regardless of extension'
      type: 'boolean'
      default: false
      order: 1
    extensions:
      title: 'Autoactivated file extensions'
      description: 'List of file extenstions which should have the wordcount plugin enabled'
      type: 'array'
      default: [ 'md', 'markdown', 'readme', 'txt', 'rst', 'adoc', 'log', 'msg' ]
      items:
        type: 'string'
      order: 2
    noextension:
      title: 'Autoactivate for files without an extension'
      description: 'Wordcount plugin enabled for files without a file extension'
      type: 'boolean'
      default: false
      items:
        type: 'boolean'
      order: 3
    goal:
      title: 'Work toward a word goal'
      description: 'Shows a bar showing progress toward a word goal'
      type: 'number'
      default: 0
      order: 4
    goalColor:
      title: 'Color for word goal'
      type: 'color'
      default: 'rgb(0, 85, 0)'
      order: 5
    goalBgColor:
      title: 'Color for word goal background'
      type: 'color'
      default: 'red'
      order: 6
    goalLineHeight:
      title: 'Percentage height of word goal line'
      type: 'string'
      default: '20%'
      order: 7
    strip:
      title: 'Select Scopes for the Word Count'
      order: 8
      type: 'object'
      properties:
        scopes:
          title: 'Specific scopes to be used for counting'
          description: 'These settings are meant to exclude specific scopes from counting (e.g. comments, blockquotes, code blocks, punctuation) or to only count specific scopes. This is done using the [atom/first-mate](https://github.com/atom/first-mate/blob/master/spec/scope-selector-spec.coffee) scope selector, so that complex selections can be achieved if necessary.\nThis field defines a the scopes to be matched in order for text to be counted or excluded.\n`comment` or `comment.*` would exclude all comments from the count, `quote.*, fenced.code.*` all fenced code blocks and all blockquotes. According to the scope selector syntax, the asterisks are not required.\nOther suggested codes to exclude in Markdown would be `punctuation.*` and `destination.link.*`.'
          type: 'string'
          default: ''
          order: 1
        exclude:
          title: 'Negate Scope Selector'
          description: 'Negate the scope selector above. This is the suggested option, as then scopes to be ignored can be comma-separated easily.\nIf deactivated, only the grammars in the list will be counted, which may lead to empty counts on unknown documents!'
          type: 'boolean'
          default: true
          order: 2
        inSelection:
          title: 'Strip Scopes in Selections'
          type: 'boolean'
          default: true
          order: 3
    showchars:
      title: 'Show character count'
      description: 'Shows the character count from the view'
      type: 'boolean'
      default: true
      order: 12
    showwords:
      title: 'Show word count'
      description: 'Shows the word count from the view'
      type: 'boolean'
      default: true
      order: 13
    showtime:
      title: 'Show time estimation'
      description: 'Shows the time estimation from the view'
      type: 'boolean'
      default: false
      order: 14
    charactersPerSeconds:
      title: 'Character per seconds'
      description: 'This helps you estimating the duration of your text for reading.'
      type: 'number'
      default: 1000
      order: 15
    showprice:
      title: 'Show price estimation'
      description: 'Shows the price for the text per word'
      type: 'boolean'
      default: false
      order: 16
    wordprice:
      title: 'How much do you get paid per word?'
      description: 'Allows you to find out how much do you get paid per word'
      type: 'string'
      default: '0.15'
      order: 17
    currencysymbol:
      title: 'Set a different currency symbol'
      description: 'Allows you to change the currency you get paid with'
      type: 'string'
      default: '$'
      order: 18

  activate: (state) ->
    @visible = false
    view = new WordcountView()

    # Updates only the count of the s
    update_count = _.throttle (editor) =>
      @visible && view.update_count(editor)
    , 300

    # Update count when content of buffer or selections change
    atom.workspace.observeTextEditors (editor) ->
      editor.onDidChange -> update_count editor

      # NOTE: This triggers before a didChangeActivePane, so the counts might be calculated once on pane switch
      editor.onDidChangeSelectionRange -> update_count editor

    # Updates the visibility and count of the view
    update_view_and_count = (item) =>
      @show_or_hide_for_item item
      editor = atom.workspace.getActiveTextEditor()
      update_count editor if editor?

    # Update whenever active item changes
    atom.workspace.onDidChangeActivePaneItem update_view_and_count

    # Initial update
    update_view_and_count atom.workspace.getActivePaneItem()

    atom.config.observe('wordcount.goal', @update_goal)

  update_goal: (item) ->
    if item is 0
      view.element.style.background = 'transparent'

  show_or_hide_for_item: (item) ->
    {alwaysOn, extensions, noextension} = atom.config.get('wordcount')
    extensions = (extensions || []).map (extension) -> extension.toLowerCase()
    buffer = item?.buffer

    not_text_editor = not buffer?
    untitled_tab = buffer?.file is null
    current_file_extension = buffer?.file?.path.match(/\.(\w+)$/)?[1].toLowerCase()

    no_extension = noextension and (not current_file_extension? or untitled_tab)

    if alwaysOn or no_extension or current_file_extension in extensions
      @visible = true
      view.element.style.display = "inline-block" unless not_text_editor
    else
      @visible = false
      view.element.style.display = "none"

  consumeStatusBar: (statusBar) ->
    tile = statusBar.addRightTile(item: view.element, priority: 100)

  deactivate: ->
    tile?.destroy()
    tile = null
