import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { runInNewContext } from 'node:vm';
import ts from 'typescript';

import { GODOT_DIRECTORY } from './godot-cli';

const element = (x: number, y: number) => ({
    current: {
        getBoundingClientRect: () => ({
            left: x,
            top: y,
            width: 0,
            height: 0,
        }),
    },
});

export function generateAttackFixtures(): void {
    const file = path.resolve(
        GODOT_DIRECTORY,
        '../src/hooks/useBattleAnimations.ts'
    );
    const source = ts.createSourceFile(
        file,
        readFileSync(file, 'utf8'),
        ts.ScriptTarget.Latest,
        true
    );
    const names = new Set([
        'buildFaultBurstParticles',
        'clamp01',
        'easeOutQuad',
        'getBattleSeverity',
        'getRegenSeverity',
        'quadraticBezier',
        'startAttackEffect',
        'startFaultEffect',
        'startHealEffect',
        'startPerfectHaloEffect',
    ]);
    const functions: string[] = [];
    const constants: string[] = [];
    const constantNames = new Set([
        'FAULT_RICOCHET_DURATION_MS',
        'FAULT_SHARD_DURATION_MS',
        'HEAL_PULSE_DURATION_MS',
        'HEAL_STREAM_DURATION_MS',
        'HEAL_STREAM_STEP_MS',
        'PERFECT_HALO_DURATION_MS',
    ]);
    function visit(node: ts.Node) {
        if (
            ts.isFunctionDeclaration(node) &&
            node.name &&
            names.has(node.name.text)
        ) {
            functions.push(node.getText(source));
        }
        if (
            ts.isVariableDeclaration(node) &&
            constantNames.has(node.name.getText(source))
        ) {
            constants.push(`const ${node.getText(source)};`);
        }
        ts.forEachChild(node, visit);
    }
    visit(source);
    if (functions.length !== names.size) {
        throw new Error(
            'Web attack implementation changed; update the animation fixture harness.'
        );
    }
    const code = ts.transpileModule([...constants, ...functions].join('\n'), {
        compilerOptions: { target: ts.ScriptTarget.ES2022 },
    }).outputText;
    const fixtures: unknown[] = [];
    for (const side of ['self', 'enemy']) {
        for (const damage of [2, 6, 16, 31]) {
            for (const elapsedMs of [
                20, 160, 360, 560, 670, 780, 910, 1050, 1100,
            ]) {
                let frame: ((timestamp: number) => void) | undefined;
                let effect: { particles: unknown[] } | undefined;
                const context = {
                    sourceSide: side,
                    targetSide: side === 'self' ? 'enemy' : 'self',
                    damage,
                    overlayRef: element(0, 0),
                    selfBlobRef: element(160, 330),
                    enemyBlobRef: element(160, 170),
                    selfHealthRef: element(160, 450),
                    enemyHealthRef: element(160, 70),
                    animationFrameRef: { current: undefined },
                    performance: { now: () => 0 },
                    requestAnimationFrame: (
                        callback: (timestamp: number) => void
                    ) => {
                        frame = callback;
                        return 1;
                    },
                    cancelAnimationFrame: () => {
                        frame = undefined;
                    },
                    setAttackEffect: (value: typeof effect) => {
                        effect = value;
                    },
                };
                // Execute the web's actual animation closure with a controlled frame clock.
                runInNewContext(
                    `${code}\nstartAttackEffect(sourceSide, targetSide, 1, damage);`,
                    context
                );
                if (!frame) {
                    throw new Error('Web attack did not schedule a frame.');
                }
                frame(elapsedMs);
                fixtures.push({
                    side,
                    damage,
                    elapsedMs,
                    particles: effect?.particles ?? [],
                });
            }
        }
    }
    const supportFixtures: unknown[] = [];
    for (const side of ['self', 'enemy']) {
        for (const kind of ['heal', 'fault', 'perfect']) {
            const effectConfig = {
                heal: {
                    amounts: [2, 6, 13, 21],
                    functionName: 'startHealEffect',
                },
                fault: {
                    amounts: [2, 6, 16, 31],
                    functionName: 'startFaultEffect',
                },
                perfect: {
                    amounts: [0],
                    functionName: 'startPerfectHaloEffect',
                },
            };
            const { amounts, functionName } =
                effectConfig[kind as keyof typeof effectConfig];
            for (const amount of amounts) {
                for (const elapsedMs of [
                    20, 160, 300, 500, 670, 800, 1100, 1300,
                ]) {
                    let particles: unknown[] = [];
                    const context = {
                        side,
                        amount,
                        getBattlePoint: (value: string, anchor: string) => {
                            const points =
                                value === 'self'
                                    ? { blob: 330, health: 450 }
                                    : { blob: 170, health: 70 };
                            return {
                                x: 160,
                                y: points[anchor as keyof typeof points],
                            };
                        },
                        startSupportParticleEffect: (
                            _id: number,
                            duration: number,
                            render: (
                                elapsed: number,
                                progress: number
                            ) => unknown[]
                        ) => {
                            particles =
                                elapsedMs < duration
                                    ? render(elapsedMs, elapsedMs / duration)
                                    : [];
                            return true;
                        },
                    };
                    runInNewContext(
                        `${code}\n${functionName}(side, 1, amount);`,
                        context
                    );
                    supportFixtures.push({
                        side,
                        kind,
                        amount,
                        elapsedMs,
                        particles,
                    });
                }
            }
        }
    }
    const output = path.join(
        GODOT_DIRECTORY,
        'tests/generated/attack-fixtures.json'
    );
    mkdirSync(path.dirname(output), { recursive: true });
    writeFileSync(output, JSON.stringify(fixtures));
    writeFileSync(
        path.join(path.dirname(output), 'support-effect-fixtures.json'),
        JSON.stringify(supportFixtures)
    );
}
