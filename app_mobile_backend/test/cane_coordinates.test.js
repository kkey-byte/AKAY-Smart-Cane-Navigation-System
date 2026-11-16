'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {caneCoordinates}=require('../services/caneCoordinates');
test('coordinates require a finite numeric pair and preserve legitimate zero coordinates',()=>{
  assert.deepEqual(caneCoordinates({latitude:0,longitude:0}),{latitude:0,longitude:0});
  assert.deepEqual(caneCoordinates({latitude:-90,longitude:180}),{latitude:-90,longitude:180});
  for(const value of [null,[],{}, {latitude:'10',longitude:20},
    {latitude:10,longitude:Infinity},{latitude:NaN,longitude:20},{latitude:10,longitude:181}])
    assert.equal(caneCoordinates(value),null);
});
