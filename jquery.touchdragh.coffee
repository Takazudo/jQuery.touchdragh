# encapsulate plugin
do ($=jQuery, window=window, document = document) ->

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
      backanim_duration: 250
      backanim_easing: 'swing'

    constructor: (@$el, options) ->

      @el = @$el[0]
      @options = $.extend {}, @defaults, options
      @disabled = false
      
      ns.startWatchGestures()
      @_handlePointerEvents()
      @_prepareEls()
      @_eventify()
      @refresh()

    refresh: ->
      @_calcMinMaxLeft()
      @_handleTooNarrow()
      @_handleInnerOver()
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

    #_handleClick: (event) =>
    #  return @
    #  event.stopPropagation()
    #  event.preventDefault()
    #  @

    _handleTouchStart: (event) =>

      return @ if @disabled

      # It'll be bugged if gestured
      return @ if ns.whileGesture

      # prevent if mouseclick
      event.preventDefault() unless ns.support.touch

      @_whileDrag = true
      @_shouldSlideInner = false

      # handle drag via OneDrag class
      d = @_currentDrag = new ns.OneDrag
      d.on 'yscrolldetected', =>
        @_whileDrag = false
      d.on 'xscrolldetected', =>
        @_shouldSlideInner = true
        @trigger 'touchdragh.start'
      d.on 'dragmove', (data) =>
        @trigger 'touchdragh.drag'
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

      # unbind everything about this drag
      $document.off ns.touchMoveEventName, @_handleTouchMove
      $document.off ns.touchEndEventName, @_handleTouchEnd

      @_currentDrag.destroy()

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
      @trigger 'touchdragh.move', data
      @

    _handleInnerOver: (triggerEvent = false) ->
      return @ if @isInnerTooNarrow()
      triggerEvent = =>
        @trigger 'touchdragh.end' if triggerEvent
      to = null
      left = ns.getLeftPx @$inner
      overMax = left > @_maxLeft
      belowMin = left < @_minLeft
      unless overMax or belowMin
        triggerEvent()
        return @
      if overMax
        to = @_maxLeft
      if belowMin
        to = @_minLeft
      d = @options.backanim_duration
      e = @options.backanim_easing
      @$inner.stop().animate { left: to }, d, e, =>
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

  # ============================================================
  # bridge to plugin

  $.fn.touchdragh = (options = {}) ->
    @each (i, el) ->
      $el = $(el)
      instance = new ns.TouchdraghEl $el, options
      $el.data 'touchdragh', instance
      @

