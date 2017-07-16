const sec = 1000
const min = 60*sec
const hr = 60*min
const day = 24*hr
const daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

prettyDate = time => (new Date(time)).toLocaleString()

function padMinutes(min) {
  const minString = min.toString()
  return (minString.length == '2' ? '' : '0') + minString
}

function isAfternoon(date) {
  return date.getHours() >= 12
}

function demilitarize(hrs) {
  return hrs - (hrs > 12 ? 12 : 0)
}

function getOptionalMinutes(minutes) {
  return minutes > 0 ? ':' + padMinutes(minutes) : ''
}

function getAmPm(hrs) {
  return hrs < 12 ? 'am' : 'pm'
}

// end needed to determine if am/pm can be omitted
function formatBlockStart(start, end) {
  const sameAmPm = isAfternoon(start) === isAfternoon(end)
  return `${daysOfWeek[start.getDay()]} ${start.getMonth()+1}/${start.getDate()} ${demilitarize(start.getHours())}${getOptionalMinutes(start.getMinutes())}${!sameAmPm ? getAmPm(start.getHours()) : ''}`
}

function formatBlockEnd(end) {
  return `${demilitarize(end.getHours())}${getOptionalMinutes(end.getMinutes())}${getAmPm(end.getHours())}`
}

function formatBlock(block) {
  // console.log(`${formatBlockStart(block.start, block.end)}-${formatBlockEnd(block.end)}`)
  return `${formatBlockStart(block.start, block.end)}-${formatBlockEnd(block.end)}`
}

// returns true if a two blocks overlap
function blocksOverlap(a, b) {
  // (new Date(events[0].start.dateTime))
  const overlaps = a.start < b.end && a.end > b.start
  // console.log('overlaps', overlaps)
  return overlaps
}

function findFreeBlocks(events, options={}, blocks=[]) {

  // set default options
  options = Object.assign({}, {
    // now to the nearest 30 min
    timeMin: Math.floor((new Date()).getTime() / (30*min)) * (30*min),
    timespanLength: 7*day,
    dayStart: 9*hr,
    dayEnd: 17*hr,
    days: [true, true, true, true, true, true, true],
    minBlockSize: hr
  }, options)

  // console.log('')
  // console.log('blocks', blocks.length)
  // console.log('events', events.length)
  // console.log('BLOCKS[0]', blocks[0])
  // console.log('BLOCKS[0]f', blocks[0] && formatBlock(blocks[0]))

  options.timeMax = options.timeMax || options.timeMin + options.timespanLength

  const timeMinDate = new Date(options.timeMin)
  // console.log('timeMin', prettyDate(timeMinDate))
  // get beginning of day
  const today = (new Date(`${timeMinDate.getFullYear()}-${timeMinDate.getMonth()+1}-${timeMinDate.getDate()} 00:00:00`)).getTime()
  // console.log('today', prettyDate(today))
  const blockEnd = today + options.dayEnd
  // console.log('blockStart', prettyDate(options.timeMin))
  // console.log('  blockEnd', prettyDate(blockEnd))

  // checks if an event overlaps in the current day
  // returns the overlapping event if it exists, otherwise returns null
  function overlaps(events) {
    // console.log(events[0] ? events[0].summary : '')
    return (
      events.length === 0 ? null :
      // exit if event is after current block
      (new Date(events[0].start.dateTime)).getTime() > blockEnd ? null :
      blocksOverlap({
        start: (new Date(events[0].start.dateTime)).getTime(),
        end: (new Date(events[0].end.dateTime)).getTime(),
      }, {
        start: options.timeMin,
        end: blockEnd
      }) ? events[0] :
      overlaps(events.slice(1)) // RECURSIVE
    )
  }

  // console.log('SUM',
  //   options.timeMin > blockEnd || '-',
  //   options.timeMin >= options.timeMax || '-',
  //   !!overlaps(events) || '-'
  // )

  return (
    // 0. if we have reached the end, return the blocks found
    options.timeMin >= options.timeMax ? blocks :

    // 1. if the day is over, proceed to the next day
    options.timeMin > blockEnd ?
      findFreeBlocks(
        events,
        Object.assign({}, options, { timeMin: today + day + options.dayStart }),
        blocks
      ) :

    // 2. if the current block overlaps with an event, exclude the overlapped events and advance recursively to the next block
    // use an IIFE to create a scope for creating a local reference to the overlapping event
    (() => {
      const overlappingEvent = overlaps(events)
      if (overlappingEvent) {
        // console.log('event end time', (new Date(overlappingEvent.end.dateTime)).toLocaleString())
      }
      // console.log('block', options.)
      // process.exit()
      return overlappingEvent ?
        findFreeBlocks(
          // since this is the first overlapping event, we can assume that all previous events won't overlap anything any more since they are in the past
          events.slice(events.indexOf(overlappingEvent)+1), // TODO: optimize
          Object.assign({}, options, {
            // begin the search again at the end of the event
            timeMin: (new Date(overlappingEvent.end.dateTime)).getTime()
          }),
          blocks.concat({
            start: new Date(options.timeMin),
            end: new Date(overlappingEvent.start.dateTime)
          })
        ) :

        // 3. otherwise append the current block to the free blocks and advance recursively to the next block
        findFreeBlocks(
          events,
          Object.assign({}, options, {
            // begin the search on the next day
            timeMin: today + day + options.dayStart
          }),
          blocks.concat({
            start: new Date(options.timeMin),
            end: new Date(today + options.dayEnd)
          })
        )
    })()
  )
}

function printFreeBlocks(...args) {
  return findFreeBlocks(...args).map(formatBlock).join('\n')
}

module.exports = {
  formatBlock,
  findFreeBlocks,
  printFreeBlocks
}
