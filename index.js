import Benchmark from 'benchmark'
import * as Reverse from './Reverse.js'

const bench = n => {
  console.info(`Array of ${n} elements benchmark:`)

  const input = [...Array(n).keys()]
  
  const suite = Benchmark.Suite()
  for (const f in Reverse)
    suite.add(f, () => Reverse[f](input))

  suite
    .on(
      'cycle',
      ({ target }) => console.info(`    ${String(target)}`)
    )
    .run()

  console.info()
}

bench(1000)
bench(10000)
