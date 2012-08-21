// Generated by CoffeeScript 1.3.3
var $;

$ = ender;

describe("Opentip - Positioning", function() {
  var adapter, opentip, triggerElementExists;
  adapter = Opentip.adapters["native"];
  opentip = null;
  triggerElementExists = true;
  beforeEach(function() {
    Opentip.adapter = adapter;
    return triggerElementExists = true;
  });
  afterEach(function() {
    var prop, _base;
    for (prop in opentip) {
      if (typeof (_base = opentip[prop]).restore === "function") {
        _base.restore();
      }
    }
    return $(".opentip-container").remove();
  });
  describe("fixed", function() {
    var element;
    element = adapter.create("<div style=\"display: block; position: absolute; top: 500px; left: 500px; width: 50px; height: 50px;\"></div>");
    beforeEach(function() {
      return adapter.append(document.body, element);
    });
    afterEach(function() {
      return $(adapter.unwrap(element)).remove();
    });
    return describe("without autoOffset", function() {
      it("should correctly position opentip when fixed without border and stem", function() {
        var elementOffset;
        opentip = new Opentip(element, "Test", {
          delay: 0,
          target: true,
          borderWidth: 0,
          stem: false,
          offset: [0, 0],
          autoOffset: false
        });
        elementOffset = adapter.offset(element);
        expect(elementOffset).to.eql({
          left: 500,
          top: 500
        });
        opentip.reposition();
        return expect(opentip.currentPosition).to.eql({
          left: 550,
          top: 550
        });
      });
      it("should correctly position opentip when fixed with", function() {
        var elementOffset;
        opentip = new Opentip(element, "Test", {
          delay: 0,
          target: true,
          borderWidth: 10,
          stem: false,
          offset: [0, 0],
          autoOffset: false
        });
        elementOffset = adapter.offset(element);
        opentip.reposition();
        return expect(opentip.currentPosition).to.eql({
          left: 560,
          top: 560
        });
      });
      it("should correctly position opentip when fixed with stem on the left", function() {
        var elementOffset;
        opentip = new Opentip(element, "Test", {
          delay: 0,
          target: true,
          borderWidth: 0,
          stem: true,
          tipJoint: "top left",
          stemLength: 5,
          offset: [0, 0],
          autoOffset: false
        });
        elementOffset = adapter.offset(element);
        opentip.reposition();
        return expect(opentip.currentPosition).to.eql({
          left: 550,
          top: 550
        });
      });
      it("should correctly position opentip when fixed on the bottom right", function() {
        var elementDimensions, elementOffset;
        opentip = new Opentip(element, "Test", {
          delay: 0,
          target: true,
          borderWidth: 0,
          stem: false,
          tipJoint: "bottom right",
          offset: [0, 0],
          autoOffset: false
        });
        opentip.dimensions = {
          width: 200,
          height: 200
        };
        elementOffset = adapter.offset(element);
        elementDimensions = adapter.dimensions(element);
        expect(elementDimensions).to.eql({
          width: 50,
          height: 50
        });
        opentip.reposition();
        return expect(opentip.currentPosition).to.eql({
          left: 300,
          top: 300
        });
      });
      return it("should correctly position opentip when fixed on the bottom right with stem", function() {
        var elementDimensions, elementOffset;
        opentip = new Opentip(element, "Test", {
          delay: 0,
          target: true,
          borderWidth: 0,
          stem: true,
          tipJoint: "bottom right",
          stemLength: 10,
          offset: [0, 0],
          autoOffset: false
        });
        opentip.dimensions = {
          width: 200,
          height: 200
        };
        elementOffset = adapter.offset(element);
        elementDimensions = adapter.dimensions(element);
        expect(elementDimensions).to.eql({
          width: 50,
          height: 50
        });
        opentip.reposition();
        return expect(opentip.currentPosition).to.eql({
          left: 300,
          top: 300
        });
      });
    });
  });
  return describe("following mouse", function() {
    return it("should correctly position opentip when following mouse");
  });
});
