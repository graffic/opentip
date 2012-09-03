
$ = ender
bean = require "bean"

describe "Ender adapter", ->
  adapter = Opentip.adapters.ender

  describe "DOM", ->
    describe "create()", ->
      it "should properly create DOM elements from string", ->
        elements = adapter.create """<div class="test"><span>HI</span></div>"""
        expect(elements).to.be.an "object"
        expect(elements.length).to.equal 1
        expect(elements[0].className).to.equal "test"

    describe "wrap()", ->
      it "should return a bonzo element", ->
        element = document.createElement "div"
        wrapped = adapter.wrap element
        expect(element).to.not.equal wrapped
        expect(element).to.equal wrapped.get(0)


    describe "tagName()", ->
      it "should return the tagName of passed ender element", ->
        element = $ "div"
        expect(adapter.tagName element).to.equal "DIV"

    describe "attr()", ->
      it "should return the attribute of passed ender element", ->
        element = $ """<a href="http://link"></a>"""
        expect(adapter.attr element, "href").to.equal "http://link"

    describe "observe()", ->
      it "should observe given event on ender element", (done) ->
        element = $ "<a>link</a>"
        adapter.observe element, "click", -> done()
        clickElement element.get(0)




