const chai = require('chai')
const findFreeBlocks = require('../find-free-blocks.js')
const should = chai.should()
const events = require('../events.json')

describe('avail', () => {
  it('should find all free blocks', () => {
    findFreeBlocks(events).should.deep.equal([])
  })
})
