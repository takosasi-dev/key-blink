// 全部の画面を 5 つの大きさで撮る(UI の作り直しの前後を見比べる用)。Chrome 1 回の起動で、画面ごとに窓の大きさだけ替えて撮る。
//     node tests/web/shots.mjs before     → build/web_shots/before/<画面>_<幅>x<高さ>.png
//     node tests/web/shots.mjs after
//     KB_QUICK=1 …                        逃げ bot の回(山場と新しい記録の結果、3 分)を飛ばす
// スマホ(390×844)は「記録だけ」(落ちない・字が読める、を見る)。作りは KeySwat の tests/web/shots.mjs。
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { open, OUT, serve, sleep } from './lib.mjs';

const PHASE = process.argv[2] || 'after';
const DIR = path.join(OUT, PHASE);
mkdirSync(DIR, { recursive: true });
const SIZES = [[1280, 720], [1920, 1080], [1024, 768], [2560, 1080], [390, 844]];
const site = serve();
const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });

async function shootAll(name, settle = 250) {
	for (const [w, h] of SIZES) {
		await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: false });
		await sleep(settle);
		const data = (await page.cdp.send('Page.captureScreenshot', { format: 'png' })).data;
		writeFileSync(path.join(DIR, `${name}_${w}x${h}.png`), Buffer.from(data, 'base64'));
	}
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
	await sleep(150);
}

try {
	console.log(`起動 ${page.bootMs} ms`);
	await page.waitState((s) => s.screen === 'gate', 30000);
	console.log(`S0 まで ${Date.now() - page.t0} ms`);
	await sleep(1200);
	await shootAll('s0');
	await page.key('x');
	await page.waitState((s) => s.screen === 'title');
	await sleep(900);
	await shootAll('s1_title_first', 300);
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'settings');
	await sleep(600);
	await shootAll('s4_settings');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'play');
	await page.waitState((s) => s.play?.tick >= 150, 5000);
	await shootAll('s2_start', 120);
	await page.key('j');
	// 何もしないと 15 秒ほどで負けるので、弾と敵が揃わなくても 7.5 秒(900 tick)で撮る(負けて結果に入ってから撮らない)
	await page.waitState((s) => (s.play?.bullets >= 3 && s.play?.enemies >= 2) || s.play?.tick >= 900, 20000);
	await shootAll('s2_play', 80);
	await page.key('Escape');
	await page.waitState((s) => s.paused, 3000);
	await sleep(500);
	await shootAll('s5_pause');
	await page.key('Escape');
	await page.waitState((s) => !s.paused, 3000);
	await page.waitState((s) => s.screen === 'result', 120000);
	await sleep(1500);
	await shootAll('s3_result', 300);
	await page.key('r');
	await page.waitState((s) => s.screen === 'play', 3000);
	await page.waitState((s) => s.screen === 'result', 120000);
	await sleep(1500);
	await shootAll('s3_result_second', 300);
	await page.clickButton('title');
	await page.waitState((s) => s.screen === 'title', 3000);
	await sleep(900);
	await shootAll('s1_title_record', 300);
	const base = page.url0.split('?')[0];
	await page.goto(base + '?keys=1&debug=1');
	await page.waitState((s) => s.screen === 'gate', 20000);
	await page.key('x');
	await page.waitState((s) => s.screen === 'keys', 3000);
	for (const c of 'asdf;/') { await page.key(c); await sleep(30); }
	await sleep(500);
	await shootAll('keys');
	// 逃げ bot の回: 山場(波 10 以降)と、それまでの回より高い点の結果(新しい記録)
	if (!process.env.KB_QUICK) {
		await page.goto(base + '?debug=1&auto=dodge');
		await page.waitState((s) => s.play?.wave >= 10 && s.play?.bullets >= 5 && s.play?.enemies >= 4, 240000);
		await shootAll('s2_climax', 60);
		await page.waitState((s) => s.screen === 'result', 240000);
		await sleep(1800);
		await shootAll('s3_result_best', 300);
	}
	console.log(`コンソールのエラー ${page.errors().length} 件(読み込み中の画面を撮る前まで)`);
	for (const e of page.errors()) console.log('  ' + e.text);
	// 読み込み中の画面(index.wasm を止めて、Godot が立ち上がる前の画面のまま撮る)
	await page.cdp.send('Network.setBlockedURLs', { urls: ['*index.wasm*'] });
	await page.cdp.send('Page.navigate', { url: base });
	await sleep(2500);
	await shootAll('loading', 200);
	await page.cdp.send('Network.setBlockedURLs', { urls: [] });
} finally {
	await page.close();
	site.stop();
}
