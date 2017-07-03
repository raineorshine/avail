const sec = 1000
const min = 60*sec
const hr = 60*min
const day = 24*hr

module.exports = function findFreeBlocks(events, options={
  timeMin: Math.floor((new Date()).getTime() / (30*min)) * (30*min),
  timespanLength: 14*day,
  dayStart: 9*hr,
  dayEnd: 19*hr,
  minBlockSize: day//30*min
}, blocks=[]) {

  options.timeMax = options.timeMax || options.timeMin + options.timespanLength

  function overlaps() {
    return false
  }

  console.log((new Date(options.timeMin)).toLocaleString())
  return (
    // 1. if we have reached the end, return the blocks found
    options.timeMin >= options.timeMax ? blocks :

    // 2. if the current block overlaps with an event, exclude the overlapped events and advance recursively to the next block
    overlaps() ?
      findFreeBlocks(
        events.slice(1),
        Object.assign({}, options, { timeMin: options.timeMin + options.minBlockSize }),
        blocks
      ) :
    // 3. otherwise append the current block to the free blocks and advance recursively to the next block
    blocks.concat(findFreeBlocks(
      events,
      Object.assign({}, options, { timeMin: options.timeMin + options.minBlockSize }),
      blocks.concat({ start: options.timeMin, end: options.timeMin + options.minBlockSize }))
    )
  )
}
