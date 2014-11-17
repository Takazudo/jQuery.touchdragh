# encapsulate plugin
do ($=jQuery, window=window, document=document) ->

  $window = $(window)
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

    return res

  # ============================================================
  # calcHighestHeight
  
  ns.calcHighestHeight = ($els) ->
    highest = 0
    $els.each (i, el) ->
      h = $(el).outerHeight()
      if h > highest
        highest = h
    return highest

  # ============================================================
  # detect / normalize event names

  ns.support = {}
  ns.ua = {}

  ns.support.addEventListener = 'addEventListener' of document

  # from Modernizr
  ns.support.touch = 'ontouchend' of document

  # http://msdn.microsoft.com/en-us/library/ie/hh673557(v=vs.85).aspx
  ns.support.mspointer = window.navigator.msPointerEnabled or false

  # switch transition by transit plugin.
  ns.support.transition = do ->
    return true if $.support.transition and $.support.transform and $.fn.transition?
    return false

  ns.transitionEnabled = ns.support.transition

  ns.enableTransition = ->
    return unless ns.support.transition
    ns.support.transition = true
    return

  ns.disableTransition = ->
    return unless ns.support.transition
    ns.support.transition = false
    return

  # http://msdn.microsoft.com/en-us/library/ie/hh920767(v=vs.85).aspx
  ns.ua.win8orhigh = do ->
    # windows browsers has str like "Windows NT 6.2" in its UA
    # Win8 UAs' version is "6.2"
    # browsers above this version may has touch events.
    ua = navigator.userAgent
    matched = ua.match(/Windows NT ([\d\.]+)/)
    return false unless matched
    version = matched[1] * 1
    return false if version < 6.2
    return true

  # returns related eventNameSet
  ns.getEventNameSet = (eventName) ->
    res = {}
    switch eventName
      when 'touchstart'
        res.move = 'touchmove'
        res.end = 'touchend'
      when 'mousedown'
        res.move = 'mousemove'
        res.end = 'mouseup'
      when 'MSPointerDown'
        res.move = 'MSPointerMove'
        res.end = 'MSPointerUp'
      when 'pointerdown'
        res.move = 'pointermove'
        res.end = 'pointerup'
    return res
  
  # ============================================================
  # left value getter

  ns.getLeftPx = ($el) ->
    if ns.transitionEnabled
      prop = 'x'
    else
      prop = 'left'
    l = $el.css prop
    if l is 'auto'
      l = 0
    else
      l = (l.replace /px/, '') * 1
    return l

  # ============================================================
  # gesture handler

  ns.startWatchGestures = do ->
    initDone = false
    init = ->
      initDone = true
      $document.bind 'gesturestart', ->
        ns.whileGesture = true
      $document.bind 'gestureend', ->
        ns.whileGesture = false
    return ->
      return if @initDone
      init()

  # ============================================================
  # OneDrag

  class ns.OneDrag extends window.EveEve
    
    constructor: ->

      @_scrollDirectionDecided = false

    applyTouchStart: (touchStartEvent) ->

      coords = ns.normalizeXY touchStartEvent
      @startPageX = coords.x
      @startPageY = coords.y

      return this

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
      return this

    destroy: ->
      @off()
      return this

  # ============================================================
  # TouchdraghEl

  class ns.TouchdraghEl extends window.EveEve

    defaults:
      inner: '> *' # selector
      backanim_duration: 250
      backanim_easing: 'swing'
      beforefirstrefresh: null # fn
      triggerrefreshimmediately: true
      tweakinnerpositionstyle: false
      alwayspreventtouchmove: false
      dragger: null
      useonlydragger: false
      forever: false
      mstouchaction: 'pan-y'

    constructor: (@$el, options) ->

      @el = @$el[0]
      @options = $.extend {}, @defaults, options
      @disabled = false

      @_prepareDraggers()

      ns.startWatchGestures()
      @_handlePointerEvents()
      @_prepareEls()
      @_eventify()
      @refresh() if @options.triggerrefreshimmediately

    _prepareDraggers: ->

      if @options.useonlydragger
        @$draggers = $()
      else
        @$draggers = @$el

      if @options.dragger
        @$draggers = @$draggers.add $(@options.dragger)

      return this
      

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
      return this

    _handlePointerEvents: ->
      return @ unless ns.support.mspointer
      @el.style.msTouchAction = @options.mstouchaction
      return this

    _prepareEls: ->
      @$inner = @$el.find @options.inner
      if @options.tweakinnerpositionstyle
        @$inner.css
          position: 'relative'
      if ns.transitionEnabled
        @$inner.css { x: 0 }
      return this
    
    _calcMinMaxLeft: ->
      if @options.forever
        # don't set min/max. it loops forever.
        @_maxLeft = null
        @_minLeft = null
      else
        @_maxLeft = 0
        @_minLeft = -(@$inner.outerWidth() - @$el.innerWidth())
      return this

    _eventify: ->
      eventNames = 'pointerdown MSPointerDown touchstart mousedown'
      @$draggers.bind eventNames, @_handleTouchStart
      if ns.support.addEventListener
        @el.addEventListener 'click', $.noop , true
      return this

    _handleClickToIgnore: (event) =>
      event.stopPropagation()
      event.preventDefault()
      return this

    _handleTouchStart: (event) =>

      return this if @disabled
      return this if @_whileDrag

      # It'll be bugged if gestured
      return this if ns.whileGesture

      # prevent if mouseclick
      event.preventDefault() if event.type is 'mousedown'

      # detect eventNameSet then save
      @_currentEventNameSet = ns.getEventNameSet event.type

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
        # ignore click if drag
        @$el.delegate 'a', 'click', @_handleClickToIgnore
      d.on 'dragmove', (data) =>
        @trigger 'drag'
        @_moveInner data.x

      @_innerStartLeft = ns.getLeftPx @$inner

      d.applyTouchStart event

      # Let's observe move/end now
      $document.bind @_currentEventNameSet.move, @_handleTouchMove
      $document.bind @_currentEventNameSet.end, @_handleTouchEnd

      return this

    _handleTouchMove: (event) =>

      return this unless @_whileDrag
      return this if ns.whileGesture

      @_currentDrag.applyTouchMove event

      if @options.alwayspreventtouchmove or @_shouldSlideInner
        event.preventDefault()
        event.stopPropagation()
      return this

    _handleTouchEnd: (event) =>

      @_whileDrag = false

      # unbind everything about this drag
      $document.unbind @_currentEventNameSet.move, @_handleTouchMove
      $document.unbind @_currentEventNameSet.end, @_handleTouchEnd

      @_currentDrag.destroy()

      # we don't need nameset anymore
      @_currentEventNameSet = null

      @trigger 'dragend' unless @_slidecanceled

      # enable click again
      setTimeout =>
        @$el.undelegate 'a', 'click', @_handleClickToIgnore
      , 10

      # if inner was over, fit it to inside.
      @_handleInnerOver true
      return this

    _moveInner: (x) ->
      left = @_innerStartLeft + x

      # slow down if over
      unless @_maxLeft is null
        if (left > @_maxLeft)
          left = @_maxLeft + ((left - @_maxLeft) / 3)
        else if (left < @_minLeft)
          left = @_minLeft + ((left - @_minLeft) / 3)

      if ns.transitionEnabled
        to = { x: left }
      else
        to = { left: left }

      @$inner.css to
      data = { left: left }

      @trigger 'move', data
      return this

    _handleInnerOver: (invokeEndEvent = false) ->

      return this if @isInnerTooNarrow()

      triggerEvent = =>
        @trigger 'moveend' if invokeEndEvent
      to = null

      left = @currentSlideLeft()

      if @_maxLeft is null
        triggerEvent()

      else

        # check if left is over
        overMax = left > @_maxLeft
        belowMin = left < @_minLeft
        unless overMax or belowMin
          triggerEvent()
          return this

        # normalize left
        to = @_maxLeft if overMax
        to = @_minLeft if belowMin

        # then do slide
        @slide to, true, =>
          triggerEvent()
      
      return this

    _handleTooNarrow: ->
      if @isInnerTooNarrow()
        @disable()
        @$inner.css 'left', 0
      else
        @enable()
      return this

    isInnerTooNarrow: ->
      elW = @$el.width()
      innerW = @$inner.width()
      innerW <= elW

    disable: ->
      @disabled = true
      return this

    enable: ->
      @disabled = false
      return this

    slide: (val, animate=false, callback) ->

      unless @_maxLeft is null
        val = @_maxLeft if val > @_maxLeft
        val = @_minLeft if val < @_minLeft

      d = @options.backanim_duration
      e = @options.backanim_easing

      if ns.transitionEnabled
        to = x: val
      else
        to = left: val

      return $.Deferred (defer) =>
        @trigger 'beforeslide'
        onDone = =>
          @trigger 'afterslide'
          callback?()
          defer.resolve()
        if animate
          if ns.transitionEnabled
            e = 'easeOutExpo' # use transit's easing
            @$inner.stop().transition to, d, e, => onDone()
          else
            @$inner.stop().animate to, d, e, => onDone()
        else
          @$inner.stop().css to
          onDone()
      .promise()

    currentSlideLeft: ->
      ns.getLeftPx @$inner

    isCurrentLeftMax: ->
      return @currentSlideLeft() is @_minLeft

    isCurrentLeftMin: ->
      return @currentSlideLeft() is @_maxLeft

    updateInnerWidth: (val) ->
      @$inner.width val
      return this

  # ============================================================
  # TouchdraghFitty

  class ns.TouchdraghFitty extends window.EveEve
    
    defaults:
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
          @options.beforefirstrefresh?(this)
          @trigger 'firstrefresh', this
          @_firstRefreshDone = true

        touchdragh.on 'refresh', => @trigger 'refresh'
        touchdragh.on 'slidecancel', => @trigger 'slidecancel'
        touchdragh.on 'dragstart', => @trigger 'dragstart'
        touchdragh.on 'drag', => @trigger 'drag'
        touchdragh.on 'dragend', => @trigger 'dragend'

        touchdragh.on 'moveend', =>
          slidedDistance = -touchdragh.currentSlideLeft()
          itemW = @$el.innerWidth()
          nextIndex = null
          caliculatedIndex = slidedDistance / itemW
          if caliculatedIndex < @currentIndex
            nextIndex = @currentIndex - 1
          else if caliculatedIndex > @currentIndex
            nextIndex = @currentIndex + 1
          unless nextIndex is null
            @updateIndex nextIndex
            @adjustToFit itemW, true
      @_touchdragh = new ns.TouchdraghEl @$el, options
      return this
      
    updateIndex: (index) ->
      unless 0 <= index < @$items.length
        return false
      lastIndex = @currentIndex
      @currentIndex = index
      if lastIndex isnt index
        data =
          index: @currentIndex
        @trigger 'indexchange', data
      return true

    refresh: ->
      @$items = @$el.find @options.item
      itemW = @_itemWidth = @$el.innerWidth()
      innerW = (itemW * @$items.length)
      @_touchdragh.updateInnerWidth innerW
      @$items.width itemW
      @_touchdragh.refresh()
      @adjustToFit itemW
      return this

    adjustToFit: (itemWidth, animate=false, callback) ->
      itemWidth = @$items.width() unless itemWidth?
      return $.Deferred (defer) =>
        i = @currentIndex
        left_after = -itemWidth * i
        left_pre = @_touchdragh.currentSlideLeft()
        if left_after is left_pre
          defer.resolve()
          return this
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
      return $.Deferred (defer) =>
        if updated
          @adjustToFit null, animate, => defer.resolve()
        else
          @trigger 'invalidindexrequested'
          defer.resolve()
      .promise()

    next: (animate=false) ->
      return @to (@currentIndex + 1), animate

    prev: (animate=false) ->
      return @to (@currentIndex - 1), animate

  # ============================================================
  # ForeverInner

  class ns.ForeverInner extends window.EveEve

    defaults:
      baseleft: null
      stepwidth: null # pixel as number
      widthbetween: null # pixel as number
      forever_duplicate_count: 1

    constructor:  (@$inner, @$inner2, options) ->
      o = @options = $.extend {}, @defaults, options
      l = (@$inner2.find o.selector_item).length
      @origItemsCount = l
      @baseIndex = l * o.forever_duplicate_count
      @_duplicateInside()

    handleIndexchange: (index) ->
      offsetCount = null
      if index < @baseIndex
        i = -1
        loop
          from = @baseIndex + i * @origItemsCount
          to = @baseIndex + (i+1) * @origItemsCount
          if from <= index < to
            offsetCount = i
            break
          i -= 1
      if index >= @baseIndex
        i = 0
        loop
          from = @baseIndex + i * @origItemsCount
          to = @baseIndex + (i+1) * @origItemsCount
          if from <= index < to
            offsetCount = i
            break
          i += 1
      @_changeLeftFromOffset offsetCount
      @_handleInner2Width()
      return this

    _changeLeftFromOffset: (offsetCount) ->
      o = @options
      widthPerOffset = @origItemsCount * (o.stepwidth + o.widthbetween)
      val = o.baseleft + offsetCount * widthPerOffset
      @currentInner2Left = val
      @$inner2.css 'left', val
      return this

    _handleInner2Width: ->
      @$inner2.width @$inner.width() - @options.baseleft + 3

    _duplicateInside: ->
      src = @$inner2.html()
      for [1..(@options.forever_duplicate_count * 2)]
        @$inner2.append src
      return this

  # ============================================================
  # TouchdraghSteppy

  class ns.TouchdraghSteppy extends window.EveEve
    
    defaults:
      item: null # selector
      inner: null # selector
      inner2: null # selector
      inner2left: 0 # left px value
      beforefirstfresh: null # fn
      startindex: 0
      maxindex: 'auto' # 'auto' or number
      triggerrefreshimmediately: true
      stepwidth: 300
      widthbetween: 0
      forever: false
      forever_duplicate_count: 1
      normalize_height: false
      normalize_height_on_resize: false

    constructor: (@$el, options) ->
      o = @options = $.extend {}, @defaults, options
      @steppy_disabled = false
      @currentIndex = o.startindex
      @_setupForever()
      @_prepareTouchdragh()
      @refresh() if o.triggerrefreshimmediately
      @_eventify()

      if o.forever
        @to @_foreverInner.baseIndex + o.startindex # move to baseIndex
        @on 'indexchange', (data) ->
          @_foreverInner.handleIndexchange data.index

    _eventify: ->
      if @options.normalize_height_on_resize
        $window.bind 'resize', => @normalizeHeight()

    _setupForever: ->
      o = @options
      return this unless o.forever
      options =
        widthbetween: o.widthbetween
        stepwidth: o.stepwidth
        baseleft: o.inner2left
        forever_duplicate_count: o.forever_duplicate_count
        selector_item: o.item
      @$inner = @$el.find o.inner
      @$inner2 = @$el.find o.inner2
      @_foreverInner = new ns.ForeverInner @$inner, @$inner2, options
      return this

    _prepareTouchdragh: ->
      
      options = $.extend {}, @options
      options.triggerrefreshimmediately = false

      options.beforefirstrefresh = (touchdragh) =>

        touchdragh.once 'firstrefresh', =>
          @options.beforefirstrefresh?(this)
          @trigger 'firstrefresh', this
          @_firstRefreshDone = true

        touchdragh.on 'refresh', => @trigger 'refresh'
        touchdragh.on 'slidecancel', => @trigger 'slidecancel'
        touchdragh.on 'dragstart', => @trigger 'dragstart'
        touchdragh.on 'drag', => @trigger 'drag'
        touchdragh.on 'dragend', => @trigger 'dragend'
        touchdragh.on 'moveend', @_handleMoveend

      @touchdragh = new ns.TouchdraghEl @$el, options
      return this

    _handleMoveend: =>
      if @steppy_disabled
        return
      index = @_calcIndexFromCurrentSlideLeft()
      @updateIndex index
      @adjustToFit true

    _calcIndexFromCurrentSlideLeft: ->

      left = @touchdragh.currentSlideLeft()

      index = 0
      nextIndex = null

      onStepLine = false
      goingToPositive = false
      goingToNegative = false

      # caliculation strategies

      handlePositiveLeft = =>
        loop
          minLeft = @_calcLeftFromIndex index
          maxLeft = @_calcLeftFromIndex (index - 1)
          halfLeft = minLeft + (maxLeft - minLeft - @options.widthbetween) / 2
          if minLeft <= left <= maxLeft
            if (left is minLeft) or (left is maxLeft)
              onStepLine = true
            if left >= halfLeft
              nextIndex = index - 1
              goingToPositive = true
            else
              nextIndex = index
              goingToNegative = true
          if nextIndex is null
            index -= 1
          else
            break

      handleNegativeLeft = =>
        loop
          if (not @options.forever) and (index > @_maxindex)
            break
          minLeft = @_calcLeftFromIndex (index + 1)
          maxLeft = @_calcLeftFromIndex index
          halfLeft = minLeft + (maxLeft - minLeft + @options.widthbetween) / 2
          if minLeft <= left <= maxLeft
            if (left is minLeft) or (left is maxLeft)
              onStepLine = true
            if left >= halfLeft
              nextIndex = index
              goingToPositive = true
            else
              nextIndex = index + 1
              goingToNegative = true
          if nextIndex is null
            index += 1
          else
            break

      # choose which strategy to use

      if @options.forever
        if left is 0
          onStepLine = true
        if left < 0
          handleNegativeLeft()
        if left > 0
          handlePositiveLeft()
      else
        handleNegativeLeft()

      # if index was not changed but some drag was occured,
      # let it slide
            
      if (nextIndex is @currentIndex) and (not onStepLine)
        if goingToPositive
          nextIndex += 1
        else if goingToNegative
          nextIndex -= 1
          
      # handle over index
      if nextIndex < 0
        nextIndex = 0
      if nextIndex > @_maxindex
        nextIndex = @_maxindex

      return nextIndex
    
    updateIndex: (index) ->
      if @options.forever is false
        unless 0 <= index <= @_maxindex
          return false
      lastIndex = @currentIndex
      @currentIndex = index
      if lastIndex isnt index
        data =
          index: @currentIndex
        if @options.forever
          data.normalizedIndex = @_calcNormalizedIndex()
        @trigger 'indexchange', data
      return true

    refresh: ->
      @$items = @$el.find @options.item
      l = @$items.length
      if @options.maxindex is 'auto'
        @_maxindex = l - 1
      else
        @_maxindex = @options.maxindex
      stepW = @options.stepwidth
      innerW = stepW * l
      if l > 0
        innerW += @options.widthbetween * (l-1)
      @touchdragh.updateInnerWidth innerW
      @$items.width stepW
      @touchdragh.refresh()
      @normalizeHeight()
      @adjustToFit()
      return this

    normalizeHeight: ->
      return this if @options.normalize_height is false
      $els = $()
        .add(@$el)
        .add(@$items)
        .add(@$inner)
        .add(@$inner2)
      $els.css 'min-height', "0px"
      h = ns.calcHighestHeight @$items
      $els.css 'min-height', "#{h}px"
      @trigger 'heightnormalized', h
      return this

    _calcLeftFromIndex: (index) ->
      stepW = @options.stepwidth
      betweenW = @options.widthbetween
      i = 0
      left = 0
      if index is 0
        return 0
      if index > 0
        while i < index
          i += 1
          left -= stepW
          left -= betweenW unless i is 0
      if index < 0
        while i > index
          i -= 1
          left += stepW
          left += betweenW unless i is 0
      return left
    
    _calcNormalizedIndex: ->
      o = @options
      l = @_foreverInner.origItemsCount
      offset = l * o.forever_duplicate_count
      index = @currentIndex - offset
      res = index % l
      if index < 0
        res = l - (Math.abs res)
        if res is l
          res = 0
      res

    adjustToFit: (animate=false, callback) ->
      stepW = @options.stepwidth
      betweenW = @options.widthbetween
      return $.Deferred (defer) =>
        left_after = @_calcLeftFromIndex @currentIndex
        left_pre = @touchdragh.currentSlideLeft()
        if left_after is left_pre
          defer.resolve()
          return this
        @trigger 'slidestart' unless @_sliding
        @_sliding = true
        @touchdragh.slide left_after, animate, =>
          @_sliding = false
          data =
            index: @currentIndex
          @trigger 'slideend', data
          callback?()
          defer.resolve()
      .promise()

    to: (index, animate=false) ->
      updated = @updateIndex index
      return $.Deferred (defer) =>
        if updated
          @adjustToFit animate, => defer.resolve()
        else
          @trigger 'invalidindexrequested'
          defer.resolve()
      .promise()

    next: (animate=false) ->
      return @to (@currentIndex + 1), animate

    prev: (animate=false) ->
      return @to (@currentIndex - 1), animate

    updateOption: (options) ->
      @options = $.extend @options, options
      @refresh()
      return this

    steppify: ->
      @steppy_disabled = false
      return this

    unsteppify: ->
      @steppy_disabled = true
      return this

  # ============================================================
  # bridge to plugin

  $.fn.touchdragh = (options) ->
    return @each (i, el) ->
      $el = $(el)
      instance = new ns.TouchdraghEl $el, options
      $el.data 'touchdragh', instance
      return

  $.fn.touchdraghfitty = (options) ->
    return @each (i, el) ->
      $el = $(el)
      instance = new ns.TouchdraghFitty $el, options
      $el.data 'touchdraghfitty', instance
      return

  $.fn.touchdraghsteppy = (options) ->
    return @each (i, el) ->
      $el = $(el)
      instance = new ns.TouchdraghSteppy $el, options
      $el.data 'touchdraghsteppy', instance
      return

  $.Touchdragh = ns.TouchdraghEl
  $.TouchdraghFitty = ns.TouchdraghFitty

