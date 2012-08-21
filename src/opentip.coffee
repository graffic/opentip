###
#
# More info at [www.opentip.org](http://www.opentip.org)
# 
# Copyright (c) 2012, Matias Meno  
# Graphics by Tjandra Mayerhold
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
###


# Opentip
# -------
#
# Usage:
# 
#     <div data-ot="This will be viewed in tooltip"></div>
# 
# or externally:
# 
#     new Opentip(element, content, title, options);
# 
# For a full documentation, please visit [www.opentip.org](http://www.opentip.org)
class Opentip

  STICKS_OUT_TOP: 1
  STICKS_OUT_BOTTOM: 2
  STICKS_OUT_LEFT: 1
  STICKS_OUT_RIGHT: 2


  class:
    container: "opentip-container"

    goingToHide: "going-to-hide"
    hidden: "hidden"
    hiding: "hiding"
    goingToShow: "going-to-show"
    showing: "showing"
    visible: "visible"

    loading: "loading"
    fixed: "fixed"
    showEffectPrefix: "show-effect-"
    hideEffectPrefix: "hide-effect-"
    stylePrefix: "style-"
  

  # Sets up and configures the tooltip but does **not** build the html elements.
  #
  # `content`, `title` and `options` are optional but have to be in this order.
  constructor: (element, content, title, options) ->
    @id = ++Opentip.lastId

    @debug "Creating Opentip."

    @adapter = Opentip.adapter

    @triggerElement = @adapter.wrap element

    throw new Error "You can't call Opentip on multiple elements." if @triggerElement.length > 1
    throw new Error "Invalid element." if @triggerElement.length < 1

    # AJAX
    @loaded = no
    @loading = no

    @visible = no
    @waitingToShow = no
    @waitingToHide = no

    # Some initial values
    @currentPosition = left: 0, top: 0
    @dimensions = width: 100, height: 50

    @content = ""

    @redraw = on

    # Make sure to not overwrite the users options object
    options = @adapter.clone options

    if typeof content == "object"
      options = content
      content = title = undefined
    else if typeof title == "object"
      options = title
      title = undefined


    # Now build the complete options object from the styles

    options.title = title if title?
    @setContent content if content?

    options.style = Opentip.defaultStyle unless options.style

    # All options are based on the standard style
    styleOptions = @adapter.extend { }, Opentip.styles.standard

    optionSources = [ ]
    # All options are based on the standard style
    optionSources.push Opentip.styles.standard
    optionSources.push Opentip.styles[options.style] unless options.style == "standard"
    optionSources.push options

    options = @adapter.extend { }, optionSources...

    options.hideTriggers.push options.hideTrigger if options.hideTrigger

    # Sanitize all positions
    options[prop] = @sanitizePosition options[prop] for prop in [
      "tipJoint"
      "targetJoint"
      "stem"
    ]

    # If the url of an Ajax request is not set, get it from the link it's attached to.
    if options.ajax and not options.ajax.url?
      if @adapter.tagName(@triggerElement) == "A"
        options.ajax = { } if typeof options.ajax != "object"
        options.ajax.url = @adapter.attr @triggerElement, "href"
      else 
        options.ajax = off

    # If the event is 'click', no point in following a link
    if options.showOn == "click" && @adapter.tagName(@triggerElement) == "A"
      @adapter.observe @triggerElement, "click", (e) ->
        e.preventDefault()
        e.stopPropagation()
        e.stopped = yes


    # Doesn't make sense to use a target without the opentip being fixed
    options.fixed = yes if options.target

    options.stem = options.tipJoint if options.stem == yes

    if options.target == yes
      options.target = @triggerElement
    else if options.target
      options.target = @adapter.wrap options.target

    @currentStemPosition = options.stem

    unless options.delay?
      options.delay = if options.showOn == "mouseover" then 0.2 else 0

    options.targetJoint = @flipPosition options.tipJoint unless options.targetJoint?

    # Used to show the opentip obviously
    @showTriggersWhenHidden = [ ]

    # Those ensure that opentip doesn't disappear when hovering other related elements
    @showTriggersWhenVisible = [ ]

    # Elements that hide Opentip
    @hideTriggers = [ ]

    # The obvious showTriggerELementWhenHidden is the options.showOn
    if options.showOn and options.showOn != "creation"
      @showTriggersWhenHidden.push
        element: @triggerElement
        event: options.showOn

    @options = options

    # Build the HTML elements when the dom is ready.
    @adapter.domReady => @_init()


  # Initializes the tooltip by creating the container and setting up the event
  # listeners.
  #
  # This does not yet create all elements. They are created when the tooltip
  # actually shows for the first time.
  #
  # This function activates the tooltip as well.
  _init: ->
    @_buildContainer()

    for hideTrigger, i in @options.hideTriggers

      hideTriggerElement = null

      hideOn = if @options.hideOn instanceof Array then @options.hideOn[i] else @options.hideOn

      if typeof hideTrigger == "string"
        switch hideTrigger
          when "trigger"
            hideOn = hideOn || "mouseout"
            hideTriggerElement = @triggerElement
          when "tip"
            hideOn = hideOn || "mouseover"
            hideTriggerElement = @container
          when "target"
            hideOn = hideOn || "mouseover"
            hideTriggerElement = this.options.target
          when "closeButton"
            # The close button gets handled later
          else
            throw new Error "Unknown hide trigger: #{hideTrigger}."
      else
        hideOn = hideOn || "mouseover"
        hideTriggerElement = @adapter.wrap hideTrigger

      if hideTriggerElement
        @hideTriggers.push
          element: hideTriggerElement
          event: hideOn

        if hideOn == "mouseout"
          # When the hide trigger is mouseout, we have to attach a mouseover
          # trigger to that element, so the tooltip doesn't disappear when
          # hovering child elements. (Hovering children fires a mouseout
          # mouseover event)
          @showTriggersWhenVisible.push
            element: hideTriggerElement
            event: "mouseover"


    @bound = { }
    @bound[methodToBind] = (do (methodToBind) => return => @[methodToBind].apply this, arguments) for methodToBind in [
      "prepareToShow"
      "prepareToHide"
      "show"
      "hide"
      "reposition"
    ]

    @activate()

    @prepareToShow() if @options.showOn == "creation"

  # This just builds the opentip container, which is the absolute minimum to
  # attach events to it.
  #
  # The actual creation of the elements is in buildElements()
  _buildContainer: ->
    @container = @adapter.create """<div id="opentip-#{@id}" class="#{@class.container} #{@class.hidden} #{@class.stylePrefix}#{@options.className}"></div>"""

    @adapter.css @container, position: "absolute"

    @adapter.addClass @container, @class.loading if @options.ajax
    @adapter.addClass @container, @class.fixed if @options.fixed
    @adapter.addClass @container, "#{@class.showEffectPrefix}#{@options.showEffect}" if @options.showEffect
    @adapter.addClass @container, "#{@class.hideEffectPrefix}#{@options.hideEffect}" if @options.hideEffect

  # Builds all elements inside the container and put the container in body.
  _buildElements: ->

    # The actual content will be set by `_updateElementContent()`
    @tooltipElement = @adapter.create """<div class="opentip"><header></header><div class="content"></div></div>"""

    @backgroundCanvas = @adapter.create """<canvas style="position: absolute;"></canvas>"""

    headerElement = @adapter.find @tooltipElement, "header"

    if @options.title
      # Create the title element and append it to the header
      titleElement = @adapter.create """<h1></h1>"""
      @adapter.update titleElement, @options.title, @options.escapeTitle
      @adapter.append headerElement, titleElement

    if @options.ajax
      @adapter.append @tooltipElement, @adapter.create """<div class="loading-indicator"><span>Loading...</span></div>"""

    if "closeButton" in @options.hideTriggers
      @adapter.append headerElement, @adapter.create """<div class="buttons"><a href="javascript:undefined;" class="close">✖</a></div>"""

    # Now put the tooltip and the canvas in the container and the container in the body
    @adapter.append @container, @backgroundCanvas
    @adapter.append @container, @tooltipElement
    @adapter.append document.body, @container


  # Sets the content and updates the HTML element if currently visible
  #
  # This can be a function or a string. The function will be executed, and the
  # result used as new content of the tooltip.
  setContent: (@content) -> @_updateElementContent() if @visible

  # Actually updates the content.
  #
  # If content is a function it is evaluated here.
  _updateElementContent: ->
    contentDiv = @adapter.find @container, ".content"

    if contentDiv?
      if typeof @content == "function"
        @debug "Executing content function."
        @content = @content this
      @adapter.update contentDiv, @content, @options.escapeHtml

    @_storeAndFixDimensions()

  # Sets width auto to the element so it uses the appropriate width, gets the
  # dimensions and sets them so the tolltip won't change in size (which can be
  # annoying when the tooltip gets too close to the browser edge)
  _storeAndFixDimensions: ->
    @adapter.css @container,
      width: "auto"
      left: "0px" # So it doesn't force wrapping
      top: "0px"
    dimensions = @adapter.dimensions @container

    @redraw = on unless @_dimensionsEqual @dimensions, dimensions

    @dimensions = dimensions
    @adapter.css @container,
      width: "#{@dimensions.width}px"
      top: "#{@currentPosition.top}px"
      left: "#{@currentPosition.left}px"

  # Sets up appropriate observers
  activate: ->
    # The order is important here!
    # "hidden" removes the observers for the `showTriggersWhenVisible` which
    # could be the same as the `showTriggersWhenHidden` which are added by
    # "hiding".
    @_setupObservers "hidden", "hiding"

  # Hides the tooltip and sets up appropriate observers
  deactivate: ->
    @debug "Deactivating tooltip."
    @hide()
    @_setupObservers "hidden"


  _setupObservers: (states...) ->
    for state in states
      switch state
        when "showing"
          # Setup the triggers to hide the tip
          for trigger in @hideTriggers
            @adapter.observe trigger.element, trigger.event, @bound.prepareToHide

          # Remove the triggers to to show the tip
          for trigger in @showTriggersWhenHidden
            @adapter.stopObserving trigger.element, trigger.event, @bound.prepareToShow

          # Start listening to window changes
          @adapter.observe (if document.onresize? then document else window), "resize", @bound.reposition
          @adapter.observe window, "scroll", @bound.reposition
        when "visible"
          # Most of the observers have already been handled by "showing"
          # Add the triggers that make sure opentip doesn't hide prematurely
          for trigger in @showTriggersWhenVisible
            @adapter.observe trigger.element, trigger.event, @bound.prepareToShow
        when "hiding"
          # Setup the triggers to show the tip
          for trigger in @showTriggersWhenHidden
            @adapter.observe trigger.element, trigger.event, @bound.prepareToShow
          
          # Remove the triggers that hide the tip
          for trigger in @hideTriggers
            @adapter.stopObserving trigger.element, trigger.event, @bound.prepareToHide

          # No need to listen for window changes anymore
          @adapter.stopObserving (if document.onresize? then document else window), "resize", @bound.reposition
          @adapter.stopObserving window, "scroll", @bound.reposition
        when "hidden"
          # Most of the observers have already been handled by "hiding"
          # Remove the trigger that would retrigger a `show` when tip is visible.
          for trigger in @showTriggersWhenVisible
            @adapter.stopObserving trigger.element, trigger.event, @bound.prepareToShow
        else
          throw new Error "Unknown state: #{state}"

    null # No unnecessary array collection

  prepareToShow: ->
    @_abortHiding()
    return if @visible

    @debug "Showing in #{@options.delay}s."

    Opentip._abortShowingGroup @options.group if @options.group

    @preparingToShow = true

    # Even though it is not yet visible, I already attach the observers, so the
    # tooltip won't show if a hideEvent is triggered.
    @_setupObservers "showing"

    # Making sure the tooltip is at the right position as soon as it shows
    @_followMousePosition()
    @reposition()

    @_showTimeoutId = @setTimeout @bound.show, @options.delay || 0

  show: ->
    @_clearTimeouts()
    return if @visible

    return @deactivate() unless @_triggerElementExists()

    @debug "Showing now."

    Opentip._hideGroup @options.group if @options.group

    @visible = yes
    @preparingToShow = no

    @_buildElements() unless @tooltipElement?
    @_updateElementContent()

    @_loadAjax() if @options.ajax and not @loaded

    @_searchAndActivateHideButtons()

    @_startEnsureTriggerElement()

    @adapter.css @container, zIndex: Opentip.lastZIndex++

    # The order is important here! Do not reverse.
    @_setupObservers "visible", "showing"

    @reposition()

    @adapter.removeClass @container, @class.hiding
    @adapter.removeClass @container, @class.hidden
    @adapter.addClass @container, @class.goingToShow
    @setCss3Style @container, "transition-duration": "0s"

    @defer =>
      @adapter.removeClass @container, @class.goingToShow
      @adapter.addClass @container, @class.showing

      delay = 0
      delay = @options.showEffectDuration if @options.showEffect and @options.showEffectDuration
      @setCss3Style @container, "transition-duration": "#{delay}s"

      @_visibilityStateTimeoutId = @setTimeout =>
        @adapter.removeClass @container, @class.showing
        @adapter.addClass @container, @class.visible
      , delay

      @_activateFirstInput()

    # Just making sure the canvas has been drawn initially.
    # It could happen that the canvas isn't drawn yet when reposition is called
    # once before the canvas element has been created. If the position
    # doesn't change after it will never call @_draw() again.
    @_draw()

  _abortShowing: ->
    if @preparingToShow
      @debug "Aborting showing."
      @_clearTimeouts()
      @_stopFollowingMousePosition()
      @preparingToShow = false
      @_setupObservers "hiding"

  prepareToHide: ->
    @_abortShowing()

    return unless @visible

    @debug "Hiding in #{@options.hideDelay}s"

    @preparingToHide = yes

    # We start observing even though it is not yet hidden, so the tooltip does
    # not disappear when a showEvent is triggered.
    @_setupObservers "hiding"

    @_hideTimeoutId = @setTimeout @bound.hide, @options.hideDelay

  hide: ->
    @_clearTimeouts()

    return unless @visible

    @debug "Hiding!"

    @visible = no

    @preparingToHide = no

    @_stopEnsureTriggerElement()

    # The order is important here! Do not reverse.
    @_setupObservers "hidden", "hiding"

    @_stopFollowingMousePosition() unless @options.fixed


 
    @adapter.removeClass @container, @class.visible
    @adapter.removeClass @container, @class.showing
    @adapter.addClass @container, @class.goingToHide
    @setCss3Style @container, "transition-duration": "0s"

    @defer =>
      @adapter.removeClass @container, @class.goingToHide
      @adapter.addClass @container, @class.hiding

      hideDelay = 0
      hideDelay = @options.hideEffectDuration if @options.hideEffect and @options.hideEffectDuration
      @setCss3Style @container, { "transition-duration": "#{hideDelay}s" }

      @_visibilityStateTimeoutId = @setTimeout =>
        @adapter.removeClass @container, @class.hiding
        @adapter.addClass @container, @class.hidden
        @setCss3Style @container, { "transition-duration": "0s" }
      , hideDelay

  _abortHiding: ->
    if @preparingToHide
      @debug "Aborting hiding."
      @_clearTimeouts()
      @preparingToHide = no
      @_setupObservers "showing"

  reposition: (e) ->
    e ?= @lastEvent

    position = @getPosition e
    return unless position?

    {position, stem} = @_ensureViewportContainment e, position

    # If the position didn't change, no need to do anything    
    return if @_positionsEqual position, @currentPosition

    # The only time the canvas has to bee redrawn is when the stem changes.
    @redraw = on unless @_positionsEqual stem, @currentStem

    @currentPosition = position
    @currentStem = stem

    # _draw() itself tests if it has to be redrawn.
    @_draw()

    @adapter.css @container, { left: "#{position.left}px", top: "#{position.top}px" }

    # Following is a redraw fix, because I noticed some drawing errors in
    # some browsers when tooltips where overlapping.
    @defer =>
      rawContainer = @adapter.unwrap @container
      # I chose visibility instead of display so that I don't interfere with
      # appear/disappear effects.
      rawContainer.style.visibility = "hidden"
      redrawFix = rawContainer.offsetHeight
      rawContainer.style.visibility = "visible"


  getPosition: (e, tipJoint, targetJoint, stem) ->

    tipJoint ?= @options.tipJoint
    targetJoint ?= @options.targetJoint

    position = { }

    if @options.target
      # Position is fixed
      targetPosition = @adapter.offset @options.target
      targetDimensions = @adapter.dimensions @options.target

      position = targetPosition

      if targetJoint.right
        # For wrapping inline elements, left + width does not give the right
        # border, because left is where the element started, not its most left
        # position.
        unwrappedTarget = @adapter.unwrap @options.target
        if unwrappedTarget.getBoundingClientRect?
          # TODO: make sure this actually works.
          position.left = unwrappedTarget.getBoundingClientRect().right + (window.pageXOffset ? document.body.scrollLeft)
        else
          # Well... browser doesn't support it
          position.left += targetDimensions.width
      else if targetJoint.center
        # Center
        position.left += Math.round targetDimensions.width / 2

      if targetJoint.bottom
        position.top += targetDimensions.height
      else if targetJoint.middle
        # Middle
        position.top += Math.round targetDimensions.height / 2

      if @options.borderWidth
        if @options.tipJoint.left
          position.left += @options.borderWidth
        if @options.tipJoint.right
          position.left -= @options.borderWidth
        if @options.tipJoint.top
          position.top += @options.borderWidth
        else if @options.tipJoint.bottom
          position.top -= @options.borderWidth
        

    else
      # Follow mouse
      @lastEvent = e if e?
      mousePosition = @adapter.mousePosition e
      return unless mousePosition?
      position = top: mousePosition.y, left: mousePosition.x

    if @options.autoOffset
      stemLength = if @options.stem then @options.stemLength else 0

      # If there is as stem offsets dont need to be that big if fixed.
      offsetDistance = if stemLength and @options.fixed then 2 else 10

      # Corners can be closer but when middle or center they are too close
      additionalHorizontal = if tipJoint.middle and not @options.fixed then 15 else 0
      additionalVertical = if tipJoint.center and not @options.fixed then 15 else 0

      if tipJoint.right then position.left -= offsetDistance + additionalHorizontal
      else if tipJoint.left then position.left += offsetDistance + additionalHorizontal

      if tipJoint.bottom then position.top -= offsetDistance + additionalVertical
      else if tipJoint.top then position.top += offsetDistance + additionalVertical

      if stemLength
        stem ?= @options.stem
        if stem.right then position.left -= stemLength
        else if stem.left then position.left += stemLength

        if stem.bottom then position.top -= stemLength
        else if stem.top then position.top += stemLength

    position.left += @options.offset[0]
    position.top += @options.offset[1]

    if tipJoint.right then position.left -= @dimensions.width
    else if tipJoint.center then position.left -= Math.round @dimensions.width / 2

    if tipJoint.bottom then position.top -= @dimensions.height
    else if tipJoint.middle then position.top -= Math.round @dimensions.height / 2

    position

  _ensureViewportContainment: (e, position) ->
    # Sometimes the element is theoretically visible, but an effect is not yet showing it.
    # So the calculation of the offsets is incorrect sometimes, which results in faulty repositioning.
    return position: position, stem: @options.stem unless @visible and position
    
    # var sticksOut = [ this.sticksOutX(position), this.sticksOutY(position) ];
    # if (!sticksOut[0] && !sticksOut[1]) return position;

    {
      position: position
      stem: @options.stem
    }



    # var tipJ = this.options.tipJoint.clone();
    # var trgJ = this.options.targetJoint.clone();

    # var viewportScrollOffset = $(document.viewport).getScrollOffsets();
    # var dimensions = this.dimensions;
    # var viewportOffset = {left: position.left - viewportScrollOffset.left, top: position.top - viewportScrollOffset.top};
    # var viewportDimensions = document.viewport.getDimensions();
    # var reposition = false;

    # if (viewportDimensions.width >= dimensions.width) {
    #   if (viewportOffset.left < 0) {
    #     reposition = true;
    #     tipJ[0] = 'left';
    #     if (this.options.target && trgJ[0] == 'left') {trgJ[0] = 'right';}
    #   }
    #   else if (viewportOffset.left + dimensions.width > viewportDimensions.width) {
    #     reposition = true;
    #     tipJ[0] = 'right';
    #     if (this.options.target && trgJ[0] == 'right') {trgJ[0] = 'left';}
    #   }
    # }

    # if (viewportDimensions.height >= dimensions.height) {
    #   if (viewportOffset.top < 0) {
    #     reposition = true;
    #     tipJ[1] = 'top';
    #     if (this.options.target && trgJ[1] == 'top') {trgJ[1] = 'bottom';}
    #   }
    #   else if (viewportOffset.top + dimensions.height > viewportDimensions.height) {
    #     reposition = true;
    #     tipJ[1] = 'bottom';
    #     if (this.options.target && trgJ[1] == 'bottom') {trgJ[1] = 'top';}
    #   }
    # }
    # if (reposition) {
    #   var newPosition = this.getPosition(evt, tipJ, trgJ, tipJ);
    #   var newSticksOut = [ this.sticksOutX(newPosition), this.sticksOutY(newPosition) ];
    #   var revertedCount = 0;
    #   for (var i = 0; i <=1; i ++) {
    #     if (newSticksOut[i] && newSticksOut[i] != sticksOut[i]) {
    #       // The tooltip changed sides, but now is sticking out the other side of the window.
    #       // If its still sticking out, but on the same side, it's ok. At least, it sticks out less.
    #       revertedCount ++;
    #       tipJ[i] = this.options.tipJoint[i];
    #       if (this.options.target) {trgJ[i] = this.options.targetJoint[i];}
    #     }
    #   }
    #   if (revertedCount < 2) {
    #     this.currentStemPosition = tipJ;
    #     return this.getPosition(evt, tipJ, trgJ, tipJ);
    #   }
    # }
    # return position;

  _draw: ->
    # This function could be called before _buildElements()
    return unless @backgroundCanvas and @redraw

    @debug "Drawing background."

    @redraw = off

    backgroundCanvas = @adapter.unwrap @backgroundCanvas

    canvasDimensions = @adapter.clone @dimensions
    canvasPosition = [ 0, 0 ]

    if @options.borderWidth
      canvasDimensions.width += @options.borderWidth * 2
      canvasDimensions.height += @options.borderWidth * 2
      canvasPosition[0] -= @options.borderWidth
      canvasPosition[1] -= @options.borderWidth
    if @options.shadow
      canvasDimensions.width += @options.shadowBlur * 2
      # If the shadow offset is bigger than the actual shadow blur, the whole canvas gets bigger
      canvasDimensions.width += Math.max 0, @options.shadowOffset[0] - @options.shadowBlur * 2
      
      canvasDimensions.height += @options.shadowBlur * 2
      canvasDimensions.height += Math.max 0, @options.shadowOffset[1] - @options.shadowBlur * 2

      canvasPosition[0] -= Math.max 0, @options.shadowBlur - @options.shadowOffset[0]
      canvasPosition[1] -= Math.max 0, @options.shadowBlur - @options.shadowOffset[1]
    if @currentStem
      if @currentStem.left || @currentStem.right
        canvasDimensions.width += @options.stemLength
      if @currentStem.top || @currentStem.bottom
        canvasDimensions.height += @options.stemLength
      if @currentStem.left
        canvasPosition[0] -= @options.stemLength
      if @currentStem.top
        canvasPosition[1] -= @options.stemLength

    backgroundCanvas.width = canvasDimensions.width
    backgroundCanvas.height = canvasDimensions.height

    @adapter.css @backgroundCanvas,
      width: "#{backgroundCanvas.width}px"
      height: "#{backgroundCanvas.height}px"
      left: "#{canvasPosition[0]}px"
      top: "#{canvasPosition[1]}px"


    ctx = backgroundCanvas.getContext "2d"

    ctx.clearRect 0, 0, backgroundCanvas.width, backgroundCanvas.height
    ctx.beginPath()

    ctx.fillStyle = @options.background
    ctx.lineJoin = "miter"
    ctx.miterLimit = 500

    # Since borders are always in the middle and I want them outside
    hb = @options.borderWidth / 2

    if @options.borderWidth
      ctx.strokeStyle = @options.borderColor
      ctx.lineWidth = @options.borderWidth

      # Now for some math!
      #
      # I have to account for the border width when implementing the stems.
      #
      # If I just draw the stem size specified the stem will be bigger if the 
      # border width is greater than 0
      #
      #
      #      /
      #     /|\
      #    / | angle
      #   /  |  \
      #  /   |   \
      # /____|____\
      # This is the angle of the tip
      halfAngle = Math.atan (@options.stemBase / 2) / @options.stemLength
      angle = halfAngle * 2

      rhombusSide = hb / Math.sin angle

      distanceBetweenTips = 2 * rhombusSide * Math.cos halfAngle
      stemLength = hb + @options.stemLength - distanceBetweenTips

      console.error "Sorry but your stemLength / stemBase ratio is strange." if stemLength < 0

      stemLength = Math.max 0, stemLength

      # Now calculate the new base
      stemBase = (Math.tan(halfAngle) * stemLength) * 2
    else
      stemLength = @options.stemLength
      stemBase = @options.stemBase



    # Draws a line with stem if necessary
    drawLine = (length, stem, first) =>
      if first
        # This ensures that the outline is properly closed
        ctx.moveTo Math.max(stemBase, @options.borderRadius) + 1 - hb, -hb
      if stem
        ctx.lineTo length / 2 - stemBase / 2, -hb
        ctx.lineTo length / 2, - stemLength - hb
        ctx.lineTo length / 2 + stemBase / 2, -hb

    # Draws a corner with stem if necessary
    drawCorner = (stem, last) =>
      if stem
        ctx.lineTo -stemBase + hb, 0 - hb
        ctx.lineTo stemLength + hb, -stemLength - hb
        ctx.lineTo hb, stemBase - hb
      else
        ctx.lineTo -@options.borderRadius + hb, -hb
        ctx.quadraticCurveTo hb, -hb, hb, @options.borderRadius - hb
      if last
        # This ensures that the outline is properly closed
        ctx.lineTo hb, Math.max(stemBase, @options.borderRadius) + 1 - hb


    # Start drawing without caring about the shadows or stems
    # The canvas position is exactly the amount that has been moved to account
    # for shadows and stems
    ctx.translate -canvasPosition[0], -canvasPosition[1]

    ctx.save()

    do => # Wrapping variables

      # This part is a bit funky...
      # All in all I just iterate over all four corners, translate the canvas
      # to it and rotate it so the next line goes to the right.
      # This way I can call drawLine and drawCorner withouth them knowing which
      # line their actually currently drawing.
      for i in [0...Opentip.positions.length/2]
        positionIdx = i * 2

        positionX = if i == 0 or i == 3 then 0 else @dimensions.width
        positionY = if i < 2 then 0 else @dimensions.height
        rotation = (Math.PI / 2) * i
        lineLength = if i % 2 == 0 then @dimensions.width else @dimensions.height
        lineStem = Opentip.positions[positionIdx]
        cornerStem = Opentip.positions[positionIdx + 1]

        ctx.save()
        ctx.translate positionX, positionY
        ctx.rotate rotation
        drawLine lineLength, @currentStem?.toString() == lineStem, i == 0
        ctx.translate lineLength, 0
        drawCorner @currentStem?.toString() == cornerStem, i == 3
        ctx.restore()

    ctx.save()

    if @options.shadow
      ctx.shadowColor = @options.shadowColor
      ctx.shadowBlur = @options.shadowBlur
      ctx.shadowOffsetX = @options.shadowOffset[0]
      ctx.shadowOffsetY = @options.shadowOffset[1]

    ctx.fill()
    ctx.restore() # Without shadow
    ctx.stroke() if @options.borderWidth

  _searchAndActivateHideButtons: ->
    if "closeButton" in @options.hideTriggers
      for element in @adapter.findAll @container, ".close"
        @hideTriggers.push
          element: @adapter.wrap element
          event: "click"

      # Creating the observers for the new close buttons
      @_setupObservers "visible" if @visible

  _activateFirstInput: ->
    input = @adapter.unwrap @adapter.find @container, "input, textarea"
    input?.focus?()

  # Calls reposition() everytime the mouse moves
  _followMousePosition: -> @adapter.observe document.body, "mousemove", @bound.reposition unless @options.fixed

  # Removes observer
  _stopFollowingMousePosition: -> @adapter.stopObserving document.body, "mousemove", @bound.reposition unless @options.fixed


  # I thinks those are self explanatory
  _clearShowTimeout: -> clearTimeout @_showTimeoutId
  _clearHideTimeout: -> clearTimeout @_hideTimeoutId
  _clearTimeouts: ->
    clearTimeout @_visibilityStateTimeoutId
    @_clearShowTimeout()
    @_clearHideTimeout()

  # Makes sure the trigger element exists, is visible, and part of this world.
  _triggerElementExists: ->
    el = @adapter.unwrap @triggerElement
    while el.parentNode
      return yes if el.parentNode.tagName == "BODY"
      el = el.parentNode

    # TODO: Add a check if the element is actually visible
    return no

  @_loadAjax: ->
    # TODO
    throw new Error "Not supported yet."


  # Regularely checks if the element is still in the dom.
  _ensureTriggerElement: ->
    unless @_triggerElementExists()
      @deactivate()
      @_stopEnsureTriggerElement()

  # In milliseconds, how often opentip should check for the existance of the element
  _ensureTriggerElementInterval: 1000

  # Sets up an interval to call _ensureTriggerElement regularely
  _startEnsureTriggerElement: ->
    @_ensureTriggerElementTimeoutId = setInterval (=> @_ensureTriggerElement()), @_ensureTriggerElementInterval

  # Stops the interval
  _stopEnsureTriggerElement: ->
    clearInterval @_ensureTriggerElementTimeoutId



# Utils
# -----

vendors = [
  "khtml"
  "ms"
  "o"
  "moz"
  "webkit"
]

# Sets a sepcific css3 value for all vendors
Opentip::setCss3Style = (element, styles) ->
  element = @adapter.unwrap element
  for own prop, value of styles
    for vendor in vendors
      element.style["-#{vendor}-#{prop}"] = value
    element.style[prop] = value

# Defers the call
Opentip::defer = (func) -> setTimeout func, 0

# Changes seconds to milliseconds
Opentip::setTimeout = (func, seconds) -> setTimeout func, if seconds then seconds * 1000 else 0

# Turns only the first character uppercase
Opentip::ucfirst = (string) ->
  return "" unless string?
  string.charAt(0).toUpperCase() + string.slice(1)

# Converts a camelized string into a dasherized one
Opentip::dasherize = (string) ->
  string.replace /([A-Z])/g, (_, char) -> "-#{char.toLowerCase()}"

# Every position goes through this function
#
# Accepts positions in nearly every form.
#
#   - "top left"
#   - "topLeft"
#   - "top-left"
#   - "RIGHT to TOP"
# 
# All that counts is that the words top, bottom, left or right are present.
Opentip::sanitizePosition = (position) ->
  return position if typeof position == "boolean"
  return null unless position

  position = position.toLowerCase()

  verticalPosition = i for i in [ "top", "bottom" ] when ~position.indexOf i
  horizontalPosition = i for i in [ "left", "right" ] when ~position.indexOf i
  horizontalPosition = @ucfirst horizontalPosition if verticalPosition?

  position = new String "#{verticalPosition ? ""}#{horizontalPosition ? ""}"
  
  throw new Error "Unknown position: " + position unless Opentip.position[position]?

  switch horizontalPosition?.toLowerCase()
    when "left" then position.left = yes
    when "right" then position.right = yes
    else position.center = yes
  switch verticalPosition?.toLowerCase()
    when "top" then position.top = yes
    when "bottom" then position.bottom = yes
    else position.middle = yes

  position

# Turns topLeft into bottomRight
Opentip::flipPosition = (position) ->
  positionIdx = Opentip.position[position]
  # There are 8 positions, and smart as I am I layed them out in a circle.
  flippedIndex = (positionIdx + 4) % 8
  @sanitizePosition Opentip.positions[flippedIndex]

# Returns true if top and left are equal
Opentip::_positionsEqual = (posA, posB) ->
  posA? and posB? and posA.left == posB.left and posA.top == posB.top

# Returns true if width and height are equal
Opentip::_dimensionsEqual = (dimA, dimB) ->
  dimA? and dimB? and dimA.width == dimB.width and dimA.height == dimB.height


# Just forwards to console.debug if Opentip.debug is true and console.debug exists.
Opentip::debug = (args...) ->
  if Opentip.debug and console?.debug?
    args.unshift "##{@id} |"
    console.debug args... 



# Startup
# -------

# TODO write startup script



# Publicly available
# ------------------
Opentip.version = "2.0.0-dev"

Opentip.debug = off

Opentip.lastId = 0

Opentip.lastZIndex = 100


Opentip.tips = [ ]

Opentip._abortShowingGroup = ->
  # TODO

Opentip._hideGroup = ->
  # TODO

# A list of possible adapters. Used for testing
Opentip.adapters = { }

# The current adapter used.
Opentip.adapter = null

Opentip.documentIsLoaded = no


Opentip.positions = [
  "top"
  "topRight"
  "right"
  "bottomRight"
  "bottom"
  "bottomLeft"
  "left"
  "topLeft"
]
Opentip.position = { }
for position, i in Opentip.positions
  Opentip.position[position] = i


# The standard style.
Opentip.styles =
  standard:    
    # This style also contains all default values for other styles.
    #
    # Following abbreviations are used:
    #
    # - `POSITION` : a string that contains at least one of top, bottom, right or left
    # - `COORDINATE` : [ XVALUE, YVALUE ] (integers)
    # - `ELEMENT` : element or element id

    # Will be set if provided in constructor
    title: undefined

    # Whether the provided title should be html escaped
    escapeTitle: yes

    # The class name to be added to the HTML element
    className: "standard"

    # - `false` (no stem)
    # - `true` (stem at tipJoint position)
    # - `POSITION` (for stems in other directions)
    stem: no

    # `float` (in seconds)
    # If null, the default is used: 0.2 for mouseover, 0 for click
    delay: null

    # See delay
    hideDelay: 0.1

    # If target is not null, elements are always fixed.
    fixed: no

    # - eventname (eg: `"click"`, `"mouseover"`, etc..)
    # - `"creation"` (the tooltip will show when being created)
    # - `null` if you want to handle it yourself (Opentip will not register for any events)
    showOn: "mouseover"

    # - `"trigger"`
    # - `"tip"`
    # - `"target"`
    # - `"closeButton"`
    # - `ELEMENT`
    #
    # This is just a shortcut, and will be added to hideTriggers
    hideTrigger: "trigger"

    # An array of hideTriggers.
    hideTriggers: [ ]

    # - eventname (eg: `"click"`)
    # - array of event strings if multiple hideTriggers
    # - `null` (let Opentip decide)
    hideOn: null

    # `COORDINATE`
    offset: [ 0, 0 ]

    # Whether the targetJoint/tipJoint should be changed if the tooltip is not in the viewport anymore.
    containInViewport: true

    # If set to true, offsets are calculated automatically to position the tooltip. (pixels are added if there are stems for example)
    autoOffset: true

    showEffect: "appear"
    hideEffect: "fade"
    showEffectDuration: 0.3
    hideEffectDuration: 0.2

    # integer
    stemLength: 8

    # integer
    stemBase: 8

    # `POSITION`
    tipJoint: "top left"

    # - `null` (no target, opentip uses mouse as target)
    # - `true` (target is the triggerElement)
    # - `ELEMENT` (for another element)
    target: null 

    # - `POSITION` (Ignored if target == `null`)
    # - `null` (targetJoint is the opposite of tipJoint)
    targetJoint: null 

    # AJAX options object consisting of:
    #
    #   - **url**
    #   - **method**
    #
    # If opentip is attached to an `<a />` element, and no url is provided, it will use
    # The elements `href` attribute.
    ajax: off

    # You can group opentips together. So when a tooltip shows, it looks if there are others in the same group, and hides them.
    group: null

    escapeHtml: false

    # Will be set automatically in constructor
    style: null

    # The background color of the tip
    background: "#fff18f"

    # Border radius...
    borderRadius: 5

    # Set to 0 or false if you don't want a border
    borderWidth: 1

    # Normal CSS value
    borderColor: "#f2e37b"

    # Set to false if you don't want a shadow
    shadow: yes

    # How the shadow should be blurred. Set to 0 if you want a hard drop shadow 
    shadowBlur: 10

    # Shadow offset...
    shadowOffset: [ 3, 3 ]

    # Shadow color...
    shadowColor: "rgba(0, 0, 0, 0.1)"

  slick:
    className: "slick"
    stem: true
  rounded:
    className: "rounded"
    stem: true
  glass:
    className: "glass"
  dark:
    className: "dark"
    borderColor: "#444"
    background: "rgba(0, 0, 0, 0.8)"


# Change this to the style name you want all your tooltips to have as default.
Opentip.defaultStyle = "standard"





