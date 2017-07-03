const chai = require('chai')
const avail = require('../index.js')
const should = chai.should()

describe('avail', () => {
  it('should do something', () => {
    avail().should.equal(12345)
  })
})
