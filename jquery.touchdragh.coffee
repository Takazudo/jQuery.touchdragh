# encapsulate plugin
do ($=jQuery, window=window, document=document) ->

  $document = $(document)

  ns = $.TouchdraghNs = {}

  # ============================================================
  # pageX/Y normalizer

  ns.normalizeXY = (event) ->

    res = {}
    orig = event.originalEvent

    if orig.changedTouches?
      # if it was a touch event
      touch = orig.changedTouches[0]
      res.x = touch.pageX
      res.y = touch.pageY
    else
      # jQuery cannnot handle pointerevents, so check orig.pageX/Y too.
      res.x = event.pageX or orig.pageX
      res.y = event.pageY or orig.pageY

    res

  # ============================================================
  # detect / normalize event names

  ns.support = {}
  ns.ua = {}

  ns.support.addEventListener = 'addEventListener' of document

  # from Modernizr
  ns.support.touch = 'ontouchend' of document

  # http://msdn.microsoft.com/en-us/library/ie/hh673557(v=vs.85).aspx
  ns.support.mspointer = window.navigator.msPointerEnabled or false

  # http://msdn.microsoft.com/en-us/library/ie/hh920767(v=vs.85).aspx
  ns.ua.win8 = /Windows NT 6\.2/i.test navigator.userAgent

  # for win8 modern browsers, we need to bind both events
  
  ns.touchStartEventName = do ->
    return 'MSPointerDown' if ns.support.mspointer
    return 'touchstart mousedown' if ns.ua.win8
    return 'touchstart' if ns.support.touch
    'mousedown'

  ns.touchMoveEventName = do ->
    return 'MSPointerMove' if ns.support.mspointer
    return 'touchmove mousemove' if ns.ua.win8
    return 'touchmove' if ns.support.touch
    'mousemove'

  ns.touchEndEventName = do ->
    return 'MSPointerUp' if ns.support.mspointer
    return 'touchend mouseup' if ns.ua.win8
    return 'touchend' if ns.support.touch
    'mouseup'

  # ============================================================
  # left value getter

  ns.getLeftPx = ($el) ->
    l = $el.css 'left'
    if l is 'auto'
      l = 0
    else
      l = (l.replace /px/, '') * 1
    l

  # ============================================================
  # gesture handler

  ns.startWatchGestures = do ->
    initDone = false
    init = ->
      initDone = true
      $document.on 'gesturestart', ->
        ns.whileGesture = true
      $document.on 'gestureend', ->
        ns.whileGesture = false
    ->
      return if @initDone
      init()

  # ============================================================
  # event module

  class ns.Event

    on: (ev, callback) ->
      @_callbacks = {} unless @_callbacks?
      evs = ev.split(' ')
      for name in evs
        @_callbacks[name] or= []
        @_callbacks[name].push(callback)
      @

    once: (ev, callback) ->
      @on ev, ->
        @off(ev, arguments.callee)
        callback.apply(@, arguments)

    trigger: (args...) ->
      ev = args.shift()
      list = @_callbacks?[ev]
      return unless list
      for callback in list
        if callback.apply(@, args) is false
          break
      @

    off: (ev, callback) ->
      unless ev
        @_callbacks = {}
        return @

      list = @_callbacks?[ev]
      return this unless list

      unless callback
        delete @_callbacks[ev]
        return this

      for cb, i in list when cb is callback
        list = list.slice()
        list.splice(i, 1)
        @_callbacks[ev] = list
        break
      @

  # ============================================================
  # OneDrag

  class ns.OneDrag extends ns.Event
    
    constructor: ->

      @_scrollDirectionDecided = false

    applyTouchStart: (touchStartEvent) ->

      coords = ns.normalizeXY touchStartEvent

      @startPageX = coords.x
      @startPageY = coords.y
      @

    applyTouchMove: (touchMoveEvent) ->

      coords = ns.normalizeXY touchMoveEvent

      triggerEvent = =>
        diffX = coords.x - @startPageX
        @trigger 'dragmove', { x: diffX }

      if @_scrollDirectionDecided
        triggerEvent()
      else
        distX = Math.abs(coords.x - @startPageX)
        distY = Math.abs(coords.y - @startPageY)
        if (distX > 5) or (distY > 5)
          @_scrollDirectionDecided = true
          if distX > 5
            @trigger 'xscrolldetected'
          else if distY > 5
            @trigger 'yscrolldetected'
      @

    destroy: ->
      @off()
      @

  # ============================================================
  # TouchdraghEl

  class ns.TouchdraghEl extends ns.Event

    defaults:
      inner: '> *' # selector
      backanim_duration: 250
      backanim_easing: 'swing'
      beforefirstrefresh: null # fn
      triggerrefreshimmediately: true
      disableimgdrag: true

    constructor: (@$el, options) ->

      @el = @$el[0]
      @options = $.extend {}, @defaults, options
      @disabled = false
      
      ns.startWatchGestures()
      @_handlePointerEvents()
      @_prepareEls()
      @_eventify()
      @refresh() if @options.triggerrefreshimmediately

    refresh: ->
      @_calcMinMaxLeft()
      @_handleTooNarrow()
      @_handleInnerOver()
      unless @_firstRefreshDone
        if @options.beforefirstrefresh
          @options.beforefirstrefresh(@)
        @trigger 'firstrefresh', @
        @_firstRefreshDone = true
      @trigger 'refresh', @
      @

    _handlePointerEvents: ->
      return @ unless ns.support.mspointer
      @el.style.msTouchAction = 'none'
      @

    _prepareEls: ->
      @$inner = @$el.find @options.inner
      @
    
    _calcMinMaxLeft: ->
      @_maxLeft = 0
      @_minLeft = -(@$inner.outerWidth() - @$el.innerWidth())
      @

    _eventify: ->
      #@$el.on 'click', @_handleClick
      @$el.on ns.touchStartEventName, @_handleTouchStart
      if ns.support.addEventListener
        @el.addEventListener 'click', $.noop , true
      @
      if @options.disableimgdrag
        @$el.find('img, input[type=image]').on 'dragstart', (e) ->
          e.preventDefault()

    #_handleClick: (event) =>
    #  return @
    #  event.stopPropagation()
    #  event.preventDefault()
    #  @

    _handleTouchStart: (event) =>

      return @ if @disabled
      return @ if @_whileDrag

      # It'll be bugged if gestured
      return @ if ns.whileGesture

      # prevent if mouseclick
      event.preventDefault() if event.type is 'mousedown'

      @_whileDrag = true
      @_slidecanceled = false
      @_shouldSlideInner = false

      # handle drag via OneDrag class
      d = @_currentDrag = new ns.OneDrag
      d.on 'yscrolldetected', =>
        @_whileDrag = false
        @_slidecanceled = true
        @trigger 'slidecancel'
      d.on 'xscrolldetected', =>
        @_shouldSlideInner = true
        @trigger 'dragstart'
      d.on 'dragmove', (data) =>
        @trigger 'drag'
        @_moveInner data.x

      @_innerStartLeft = ns.getLeftPx @$inner

      d.applyTouchStart event

      # Let's observe move/end now
      $document.on ns.touchMoveEventName, @_handleTouchMove
      $document.on ns.touchEndEventName, @_handleTouchEnd

      @

    _handleTouchMove: (event) =>

      return @ unless @_whileDrag
      return @ if ns.whileGesture
      @_currentDrag.applyTouchMove event
      if @_shouldSlideInner
        event.preventDefault()
        event.stopPropagation()
      @

    _handleTouchEnd: (event) =>

      @_whileDrag = false

      # unbind everything about this drag
      $document.off ns.touchMoveEventName, @_handleTouchMove
      $document.off ns.touchEndEventName, @_handleTouchEnd

      @_currentDrag.destroy()
      @trigger 'dragend' unless @_slidecanceled

      # if inner was over, fit it to inside.
      @_handleInnerOver true
      @

    _moveInner: (x) ->
      left = @_innerStartLeft + x

      # slow down if over
      if (left > @_maxLeft)
        left = @_maxLeft + ((left - @_maxLeft) / 3)
      else if (left < @_minLeft)
        left = @_minLeft + ((left - @_minLeft) / 3)

      @$inner.css 'left', left
      data = { left: left }
      @trigger 'move', data
      @

    _handleInnerOver: (invokeEndEvent = false) ->

      return @ if @isInnerTooNarrow()

      triggerEvent = =>
        @trigger 'moveend' if invokeEndEvent
      to = null

      left = @currentSlideLeft()

      # check if left is over
      overMax = left > @_maxLeft
      belowMin = left < @_minLeft
      unless overMax or belowMin
        triggerEvent()
        return @

      # normalize left
      to = @_maxLeft if overMax
      to = @_minLeft if belowMin

      # then do slide
      @slide to, true, =>
        triggerEvent()
      @

    _handleTooNarrow: ->
      if @isInnerTooNarrow()
        @disable()
        @$inner.css 'left', 0
      else
        @enable()
      @

    isInnerTooNarrow: ->
      elW = @$el.width()
      innerW = @$inner.width()
      innerW <= elW

    disable: ->
      @disabled = true
      @

    enable: ->
      @disabled = false
      @

    slide: (val, animate=false, callback) ->

      val = @_maxLeft if val > @_maxLeft
      val = @_minLeft if val < @_minLeft

      d = @options.backanim_duration
      e = @options.backanim_easing

      to = { left: val }

      $.Deferred (defer) =>
        @trigger 'beforeslide'
        onDone = =>
          @trigger 'afterslide'
          callback?()
          defer.resolve()
        if animate
          @$inner.stop().animate to, d, e, => onDone()
        else
          @$inner.stop().css to
          onDone()
      .promise()

    currentSlideLeft: ->
      ns.getLeftPx @$inner

    updateInnerWidth: (val) ->
      @$inner.width val
      @

  # ============================================================
  # TouchdraghFitty

  class ns.TouchdraghFitty extends ns.Event
    
    defaults:
      inner: null # selector
      item: null # selector
      beforefirstfresh: null # fn
      startindex: 0
      triggerrefreshimmediately: true

    constructor: (@$el, options) ->
      @options = $.extend {}, @defaults, options
      @currentIndex = @options.startindex
      @_prepareTouchdragh()
      @refresh() if @options.triggerrefreshimmediately
    
    _prepareTouchdragh: ->
    
      options = $.extend {}, @options
      options.triggerrefreshimmediately = false

      options.beforefirstrefresh = (touchdragh) =>

        touchdragh.once 'firstrefresh', =>
          @options.beforefirstrefresh?(@)
          @trigger 'firstrefresh', @
          @_firstRefreshDone = true

        touchdragh.on 'refresh', => @trigger 'refresh'
        touchdragh.on 'slidecancel', => @trigger 'slidecancel'
        touchdragh.on 'dragstart', => @trigger 'dragstart'
        touchdragh.on 'drag', => @trigger 'drag'
        touchdragh.on 'dragend', => @trigger 'dragend'

        touchdragh.on 'moveend', =>
          slidedDistance = -touchdragh.currentSlideLeft()
          itemW = @$el.innerWidth()
          index = Math.floor (slidedDistance / itemW)
          halfOver = (slidedDistance - (itemW * index)) > (itemW / 2)
          if halfOver
            index += 1
          @updateIndex index
          @adjustToFit itemW, true
      @_touchdragh = new ns.TouchdraghEl @$el, options
      @
      
    updateIndex: (index) ->
      unless 0 <= index <= @$items.length
        return false
      lastIndex = @currentIndex
      @currentIndex = index
      if lastIndex isnt index
        data =
          index: @currentIndex
        @trigger 'indexchange', data
      true

    refresh: ->
      @$items = @$el.find @options.item
      itemW = @_itemWidth = @$el.innerWidth()
      innerW = (itemW * @$items.length)
      @_touchdragh.updateInnerWidth innerW
      @$items.width itemW
      @_touchdragh.refresh()
      @adjustToFit itemW
      @

    adjustToFit: (itemWidth, animate=false, callback) ->
      itemWidth = @$items.width() unless itemWidth?
      $.Deferred (defer) =>
        i = @currentIndex
        left_after = -itemWidth * i
        left_pre = @_touchdragh.currentSlideLeft()
        if left_after is left_pre
          defer.resolve()
          return @
        @trigger 'slidestart' unless @_sliding
        @_sliding = true
        @_touchdragh.slide left_after, animate, =>
          @_sliding = false
          data =
            index: @currentIndex
          @trigger 'slideend', data
          callback?()
          defer.resolve()
      .promise()

    to: (index, animate=false) ->
      updated = @updateIndex (index)
      $.Deferred (defer) =>
        if updated
          @adjustToFit null, animate, => defer.resolve()
        else
          @trigger 'invalidindexrequested'
          defer.resolve()
      .promise()

    next: (animate=false) ->
      @to (@currentIndex + 1), animate

    prev: (animate=false) ->
      @to (@currentIndex - 1), animate
    

  # ============================================================
  # bridge to plugin

  $.fn.touchdragh = (options) ->
    @each (i, el) ->
      $el = $(el)
      instance = new ns.TouchdraghEl $el, options
      $el.data 'touchdragh', instance
      @

  $.fn.touchdraghfitty = (options) ->
    @each (i, el) ->
      $el = $(el)
      instance = new ns.TouchdraghFitty $el, options
      $el.data 'touchdraghfitty', instance
      @

  $.Touchdragh = ns.TouchdraghEl
  $.TouchdraghFitty = ns.TouchdraghFitty

