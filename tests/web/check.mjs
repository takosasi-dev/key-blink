// Web 版をまとめて確かめ、全部の画面を撮る(Chrome 1 回の起動で済ませる)。build/web_shots/ に PNG を置く。
// 1 回目: S0 → タッチの案内 → S1 → 今日のステージ(本物のキーで跳ぶ・押してから描くまで)→ 一時停止 → 設定 → タブが裏 → 何もせず負けて S3
//         → 保存と ParryDuel の保存の共存 → コピー → もう1回(R)→ タイトル → 設定 → 通信 0 件
// 2 回目: ?auto=dodge で逃げ bot に今日のステージを最後まで遊ばせ、扇・柱の予告と光線・壁・当たり・山場・クリアを撮る(3 分強)
// 3 回目: ?keys=1 のキーの確かめ
//     node tests/web/check.mjs                 手元の build/web を配って確かめる
//     KB_URL=https://…/key-blink/ node tests/web/check.mjs   公開した物を確かめる
//     KB_QUICK=1 …                             2 回目(3 分)を飛ばす
//     KB_DOCS=1 …                              README 用の 3 枚を 1280×720 に切って docs/ に置く
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { OUT, ROOT, expect, failureCount, open, serve, sleep } from './lib.mjs';

const DOCS = { s1_title_first: 'title.png', wave3_warn: 'play.png', s3_result_bot: 'result.png' };

// 撮った PNG から、ゲームの 1280×720 の所だけを切り出す(窓の余りを除く)。ページの canvas で作る
async function crop(page, src, dst) {
	const [x, y] = await page.gameCss(0, 0);
	const b64 = readFileSync(src).toString('base64');
	const out = await page.evaluate(`(async () => {
		const img = new Image();
		img.src = 'data:image/png;base64,${b64}';
		await img.decode();
		const c = document.createElement('canvas');
		c.width = 1280;
		c.height = 720;
		c.getContext('2d').drawImage(img, ${Math.round(x)}, ${Math.round(y)}, 1280, 720, 0, 0, 1280, 720);
		return c.toDataURL('image/png').slice('data:image/png;base64,'.length);
	})()`);
	writeFileSync(dst, Buffer.from(out, 'base64'));
}

const site = serve();
const page = await open(site.url + '?debug=1');
const playOf = async () => (await page.state()).play ?? {};
try {
	expect(page.booted, `起動した(${page.bootMs} ms)`);
	const s0 = await page.waitState((s) => s.screen === 'gate', 30000);
	expect(!!s0, `S0 が出る(ページを開いてから ${Date.now() - page.t0} ms)`);
	const loadedAt = Date.now();
	await page.evaluate(`localStorage.setItem('parry-duel/save', '{"version":1,"keep":"me"}')`);
	await page.shot('s0');
	await page.touch(...(await page.gameCss(640, 360)));
	await sleep(600);
	expect((await page.state()).screen === 'gate', 'タッチでは始まらない(FR-29)');
	await page.shot('s0_touch');
	await page.key('x');
	expect(!!(await page.waitState((s) => s.screen === 'title')), 'キーで S1');
	await sleep(300);
	await page.shot('s1_title_first');

	// 今日のステージ
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'play')), 'Enter で今日のステージ');
	await page.waitState((s) => s.play?.tick >= 150, 5000);
	await page.shot('s2_start');
	// 一時停止 → 設定 → 戻る → 続ける
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.paused, 3000)), 'Esc で一時停止');
	const tp = (await playOf()).tick;
	await sleep(600);
	expect((await playOf()).tick === tp, '一時停止の間は止まる');
	await page.shot('s5_pause');
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'settings', 3000)), '一時停止から設定');
	await sleep(200);
	await page.shot('s4_settings_from_pause');
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.screen === 'play' && s.paused, 3000)), '設定の Esc で一時停止に戻る');
	await page.key('Escape');
	expect(!!(await page.waitState((s) => !s.paused, 3000)), 'Esc で続ける');

	// タブが裏 → 一時停止。戻っても止まったまま
	await page.hide();
	await sleep(800);
	await page.show();
	expect(!!(await page.waitState((s) => s.paused, 5000)), 'タブが裏で一時停止');
	const th = (await playOf()).tick;
	await sleep(800);
	expect((await playOf()).tick === th, '戻っても止まったまま');
	await page.key('Escape');

	// 30 キーが全部届く(本物のキーの形で送る)
	const keys = 'qwertyuiopasdfghjkl;zxcvbnm,./';
	let reached = 0;
	for (let i = 0; i < keys.length; i++) {
		await page.key(keys[i]);
		const p = await page.waitState((s) => s.play?.key === i, 1500);
		if (p) reached++;
		await sleep(30);
	}
	expect(reached === 30, `30 キーで跳ぶ: ${reached}/30`);
	// 押してから描くまで(NFR-2): F と J を交互に
	for (let i = 0; i < 40; i++) {
		await page.key(i % 2 ? 'f' : 'j');
		await sleep(180);
	}
	await sleep(1200);
	const st1 = await page.stats();
	console.log('    押してから描くまで・1 フレーム(ms): ' + JSON.stringify(st1));
	await page.key('f');
	await page.waitState((s) => s.play?.tick >= 360 + 120, 8000);
	await page.shot('s2_wave1_second');

	// 何もせずに負ける(当たりの瞬間も撮る)
	const hit = await page.waitState((s) => s.screen !== 'play' || (s.play && s.play.invuln > 200), 30000);
	if (hit?.screen === 'play') await page.shot('s2_hit');
	const res = await page.waitState((s) => s.screen === 'result', 60000);
	expect(!!res, '残機 0 で S3');
	await sleep(900);
	await page.shot('s3_result_lost');
	const saved = await page.saved();
	expect(saved?.daily?.first != null, `保存が key-blink/save に入る: ${JSON.stringify(saved)}`);
	expect((await page.evaluate(`localStorage.getItem('parry-duel/save')`)) === '{"version":1,"keep":"me"}', 'ParryDuel の保存を消さない');
	await page.evaluate(`navigator.clipboard.writeText('').catch(() => {})`);
	await page.clickButton('copy');
	await sleep(500);
	const c1 = await page.clipboard();
	expect(c1.startsWith('KeyBlink '), `コピーのボタン: ${JSON.stringify(c1).slice(0, 90)}`);
	await page.shot('s3_result_copied');
	await page.key('r');
	expect(!!(await page.waitState((s) => s.screen === 'play', 3000)), 'もう1回(R)');
	await page.waitState((s) => s.play?.tick >= 60, 3000);
	await page.key('Escape');
	await page.waitState((s) => s.paused, 3000);
	await page.key('ArrowUp');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'title', 3000)), '一時停止からタイトルへ');
	await sleep(300);
	await page.shot('s1_title_record');
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'settings', 3000)), 'タイトルから設定');
	await sleep(200);
	await page.shot('s4_settings');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title', 3000);

	const after = page.requests.filter((r) => r.at > loadedAt);
	expect(after.length === 0, `読み込みの後の通信 ${after.length} 件(${Math.round((Date.now() - loadedAt) / 1000)} 秒見た)` + (after.length ? ': ' + after.map((r) => r.url).join(', ') : ''));
	console.log('    転送した大きさ: ' + JSON.stringify(page.sizes()));

	const base = page.url0.split('?')[0];
	// 2 回目: 逃げ bot に最後まで遊ばせて場面を撮る
	if (!process.env.KB_QUICK) {
		expect(await page.goto(base + '?debug=1&auto=dodge'), '逃げ bot の回を開き直す');
		await page.waitState((s) => s.screen !== undefined, 20000);
		const botLoadedAt = Date.now();
		const plan = {
			wave2_fan: (p) => p.wave === 2 && p.kinds.includes(1) && p.bullets >= 6,
			wave3_warn: (p) => p.warn > 0,
			wave3_fire: (p) => p.fire > 0,
			wave4_wall: (p) => p.walls > 0 && p.wave === 4,
			mid_wave7: (p) => p.wave === 7 && p.bullets >= 4 && p.enemies >= 3,
			hit: (p) => p.invuln > 225,
			climax_wave11: (p) => p.wave >= 11 && p.bullets >= 5 && p.enemies >= 4,
			clear_note: (p) => p.over,
		};
		const end = Date.now() + 240000;
		let last = null;
		while (Date.now() < end) {
			const s = await page.state();
			if (s.screen === 'result') break;
			const p = s.play;
			if (p) {
				last = p;
				for (const [label, when] of Object.entries(plan)) {
					if (when(p)) { await page.shot(label); delete plan[label]; break; }
				}
			}
			await sleep(60);
		}
		expect(Object.keys(plan).length === 0, `bot の回の場面が全部撮れた(残り: ${Object.keys(plan).join(' ') || '無し'})`);
		const r2 = await page.waitState((s) => s.screen === 'result', 10000);
		expect(!!r2, `bot の回が S3 まで届く(最後: 波 ${last?.wave} 残機 ${last?.lives} 点 ${last?.score})`);
		await sleep(900);
		await page.shot('s3_result_bot');
		console.log('    bot の回の 1 フレーム(ms): ' + JSON.stringify((await page.stats()).frame));
		// AC-21: 読み込みの後、3 分間の通信が 0 件(bot の回を最後まで遊ぶ間を数える)
		await sleep(Math.max(0, 185000 - (Date.now() - botLoadedAt)));  // 結果の画面のまま 3 分を超えるまで待つ
		const after2 = page.requests.filter((r) => r.at > botLoadedAt);
		const secs = Math.round((Date.now() - botLoadedAt) / 1000);
		expect(after2.length === 0 && secs >= 180, `bot の回の読み込みの後の通信 ${after2.length} 件(${secs} 秒見た)` + (after2.length ? ': ' + after2.map((r) => r.url).join(', ') : ''));
	}

	// 3 回目: キーの確かめ
	expect(await page.goto(base + '?keys=1&debug=1'), 'キーの確かめの画面を開き直す');
	await page.waitState((s) => s.screen === 'gate', 20000);
	await page.key('x');
	expect(!!(await page.waitState((s) => s.screen === 'keys', 3000)), '?keys=1 でキーの確かめの画面');
	await page.type('qa;/', 80);
	await sleep(300);
	await page.shot('keys');
	const kl = (await page.state()).keys.slice(-4).map((k) => `${k.pk_name}/${k.label}`);
	expect(kl.length === 4, `押したキーが出る: ${kl.join(' ')}`);

	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.slice(0, 5).map((e) => `[${((e.at - page.T0) / 1000).toFixed(1)}s] ` + String(e.text).split('\n')[0]).join(' / ') : ''));
	const warns = page.logs.filter((l) => l.level === 'warning');
	if (warns.length) console.log('    警告: ' + warns.slice(0, 5).map((w) => w.text).join(' / '));
	if (process.env.KB_DOCS) {
		for (const [label, file] of Object.entries(DOCS)) await crop(page, path.join(OUT, `${label}.png`), path.join(ROOT, 'docs', file));
		console.log('    docs/ に ' + Object.values(DOCS).join(' ') + ' を置いた');
	}
} finally {
	await page.close();
	site.stop();
}
console.log(failureCount() === 0 ? 'すべて OK' : `NG が ${failureCount()} 件`);
process.exit(failureCount() === 0 ? 0 : 1);
