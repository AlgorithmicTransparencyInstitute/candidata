// Regenerates lib/data/us_state_paths.json: one SVG path per state, used by
// the public home page's geographic map (public/_state_geo_map).
//
// Source: us-atlas v3 states-albers-10m (US Census cartographic boundaries,
// already projected to Albers USA in a 975x610 frame; ISC licence). Run once;
// the output is committed, so nothing here runs at deploy or page time.
//
//   mkdir -p /tmp/mapgen && (cd /tmp/mapgen && npm i us-atlas@3 topojson-client@3 topojson-simplify@3 d3-geo@3)
//   MAPGEN_MODULES=/tmp/mapgen/node_modules node lib/scripts/generate_us_state_paths.mjs
import { createRequire } from 'node:module';
import { writeFileSync } from 'node:fs';

const require = createRequire(`${process.env.MAPGEN_MODULES}/`);
const topo = require('us-atlas/states-albers-10m.json');
const { feature } = require('topojson-client');
const { presimplify, quantile, simplify } = require('topojson-simplify');
const { geoPath } = require('d3-geo');

// Drop the least significant ~65% of points: invisible at home-page size,
// and it keeps the inlined SVG small.
const simplified = simplify(presimplify(topo), quantile(presimplify(topo), 0.65));
const path = geoPath().digits(1);

const states = {};
for (const f of feature(simplified, simplified.objects.states).features) {
  states[f.id] = { name: f.properties.name, d: path(f), centroid: path.centroid(f).map(n => Math.round(n)) };
}

const out = {
  source: 'us-atlas@3 states-albers-10m (US Census cartographic boundaries, Albers USA), simplified',
  view_box: '0 0 975 610',
  states
};
writeFileSync(new URL('../data/us_state_paths.json', import.meta.url), JSON.stringify(out));
console.log(`${Object.keys(states).length} states`);
