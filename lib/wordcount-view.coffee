ScopeSelector = new require('first-mate').ScopeSelector

module.exports =
class WordcountView
  CSS_SELECTED_CLASS: 'wordcount-select'

  constructor: ->
    @element = document.createElement 'div'
    @element.classList.add('word-count')
    @element.classList.add('inline-block')

    @divWords = document.createElement 'div'

    @element.appendChild(@divWords)

    @wordregex = require('./wordcount-regex')();


  charactersToHMS: (c) ->
    # 1- Convert to seconds:
    temp = c * 60
    seconds = temp / atom.config.get('wordcount.charactersPerSeconds')
    # 2- Extract hours:
    #var hours = parseInt( seconds / 3600 ); // 3,600 seconds in 1 hour
    seconds = seconds % 3600
    # seconds remaining after extracting hours
    # 3- Extract minutes:
    minutes = parseInt(seconds / 60)
    # 60 seconds in 1 minute
    # 4- Keep only seconds not extracted to minutes:
    seconds = Math.round(seconds % 60)
    minutes = ('0' + minutes).slice(-2)
    seconds = ('0' + seconds).slice(-2)
    minutes + ':' + seconds

  update_count: (editor) ->
    texts = @getTexts editor
    scope = editor.getGrammar().scopeName
    wordCount = charCount = 0
    for text in texts
      [words, chars] = @count text
      wordCount += words
      charCount += chars
    str = ''
    str += "<span class='wordcount-words'>#{wordCount || 0} W</span>" if atom.config.get 'wordcount.showwords'
    str += ("<span class='wordcount-chars'>#{charCount || 0} C</span>") if atom.config.get 'wordcount.showchars'
    str += ("<span class='wordcount-time'>#{ @charactersToHMS charCount || 0}</span>") if atom.config.get 'wordcount.showtime'
    priceResult = wordCount*atom.config.get 'wordcount.wordprice'
    str += ("<span class='wordcount-price'>#{priceResult.toFixed(2) || 0} </span>") + atom.config.get 'wordcount.currencysymbol' if atom.config.get 'wordcount.showprice'
    @divWords.innerHTML = str
    if goal = atom.config.get 'wordcount.goal'
      if not @divGoal
        @divGoal = document.createElement 'div'
        @divGoal.style.width = '100%'
        @element.appendChild @divGoal
      green = Math.round(wordCount / goal * 100)
      green = 100 if green > 100
      color = atom.config.get 'wordcount.goalColor'
      colorBg = atom.config.get 'wordcount.goalBgColor'
      @divGoal.style.background = '-webkit-linear-gradient(left, ' + color + ' ' + green + '%, ' + colorBg + ' 0%)'
      percent = parseFloat(atom.config.get 'wordcount.goalLineHeight') / 100
      height = @element.clientHeight * percent
      @divGoal.style.height = height + 'px'
      @divGoal.style.marginTop = -height + 'px'

  getTexts: (editor) =>
    # NOTE: A cursor is considered an empty selection to the editor
    selectionRanges = editor.getSelectedScreenRanges()
    selectionRanges = selectionRanges.filter (range) =>
        !((range.start.row == range.end.row) & (range.start.column == range.end.column))

    texts = @getFilteredTexts editor, selectionRanges

    if selectionRanges.length > 0
        @element.classList.add @CSS_SELECTED_CLASS
    else
        @element.classList.remove @CSS_SELECTED_CLASS

    texts

  getFilteredTexts: (editor, ranges) ->
    stripSelection =  atom.config.get('wordcount.strip.inSelection')
    stripGrammars = atom.config.get('wordcount.strip.scopes')

    tokenizedLines = @getTokenizedLines editor
    @failedTokenisation = !tokenizedLines

    if ( ranges.length > 0 & !stripSelection ) | !stripGrammars | @failedTokenization
        if ranges.length > 0
            return ranges.map (r) =>
                editor.getTextInBufferRange r
        else
            return [ editor.getText() ]

    if ranges.length > 0
        return ranges.map (r) =>
            lines = tokenizedLines.slice(r.start.row, r.end.row+1)
            lines[lines.length-1] = @sliceTokenizedLine lines[lines.length-1], 0, r.end.column
            lines[0] = @sliceTokenizedLine lines[0], r.start.column, -1
            @stripText @stripScreenWrap lines, editor, r.start.row
    else
        return [ @stripText @stripScreenWrap tokenizedLines, editor, 0 ]

  getTokenizedLines: (editor) ->
    if editor.tokensForScreenRow
      return [0...editor.getScreenLineCount()].map((i) =>
          editor.tokensForScreenRow(i))
    else
      return false

  stripScreenWrap: (tokensByScreenLine, editor, startRow = 0) ->
    tokensByScreenLine.map((line, rowNum) => line.filter(
      (token, itemNum) =>
        itemNum != 0 or
        not (token.text.match(/^\s+$/) and
        editor.bufferPositionForScreenPosition([rowNum + startRow, 0]).column == 0)
    ))

  stripText: (tokensByLine) ->
    stripScopes = atom.config.get('wordcount.strip.scopes')
    excludeGrammars = atom.config.get('wordcount.strip.exclude')
    selector = new ScopeSelector stripScopes

    text = tokensByLine.map(
        (line) => line.filter(
            (token) => selector.matches(
                token.scopes.map((scope) => scope.replace(/syntax--/g, '').replace(/ /g, '.'))
            ) == !excludeGrammars
          ).map(
            (token) => token.text
          ).join('')
    ).filter(
        (line) => line.length > 0
    ).join('\n')
    text

  sliceTokenizedLine: (tokensInLine, start, end) ->
    if end == 0
      return []
    ct = 0
    cutstart = -1
    cutend = -1
    tokensInLine = tokensInLine.filter (t) =>
      if t.text.length + ct > start & cutstart < 0
        cutstart = start - ct
      ct += t.text.length
      if cutstart >= 0 & cutend < 0
        if ct > end & cutend < 0 & end >= 0
          cutend = end - ct + t.text.length
        return true
      else
        return false
    if cutstart > 0
      tokensInLine[0] = {
          scopes : tokensInLine[0].scopes
          text : tokensInLine[0].text.slice(cutstart)
          }
    if cutend > 0
      tokensInLine[tokensInLine.length-1] = {
          scopes : tokensInLine[tokensInLine.length-1].scopes
          text : tokensInLine[tokensInLine.length-1].text.slice(0, cutend)
          }
    tokensInLine

  count: (text) ->
    words = text?.match(@wordregex)?.length
    text = text?.replace '\n', ''
    text = text?.replace '\r', ''
    chars = text?.length
    [words, chars]
