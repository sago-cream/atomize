import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import { loadLocalEnv } from './load-local-env';

loadLocalEnv();

export const ROOT_DIRECTORY = path.resolve(import.meta.dirname, '../..');
export const GODOT_DIRECTORY = path.resolve(ROOT_DIRECTORY, 'godot');

export function findGodotBinary(): string | undefined {
    const configuredGodotBinary = process.env.GODOT_BIN;
    const candidateBinaries = [
        ...(configuredGodotBinary ? [configuredGodotBinary] : []),
        'godot',
        'godot4',
        '/Applications/Godot.app/Contents/MacOS/Godot',
        '/Applications/Godot_mono.app/Contents/MacOS/Godot',
    ];

    return candidateBinaries.find((candidate) => {
        if (candidate.includes(path.sep) && !existsSync(candidate)) {
            return false;
        }

        const result = spawnSync(candidate, ['--version'], {
            stdio: 'ignore',
        });

        return result.status === 0;
    });
}

export function requireGodotBinary(): string {
    const godotBinary = findGodotBinary();

    if (!godotBinary) {
        console.error(
            '[Error] Godot was not found. Install Godot 4.7 or newer, or set GODOT_BIN=/path/to/godot.'
        );
        process.exit(1);
    }

    const version = spawnSync(godotBinary, ['--version'], { encoding: 'utf8' });
    const versionText = version.stdout.trim();
    const [major, minor] = versionText.split('.', 2);
    const isSupported = Number(major) === 4 && Number(minor) >= 7;
    if (!isSupported) {
        console.error(
            `[Error] Atomize requires Godot 4.7 or newer in the 4.x series. Found ${versionText || 'an unknown version'}. Set GODOT_BIN to a supported editor and install matching export templates.`
        );
        process.exit(1);
    }
    return godotBinary;
}
