const activeSounds = new Map();

function stopSound(sound) {
    const audio = activeSounds.get(sound);
    if (!audio) return;

    audio.pause();
    audio.currentTime = 0;
    activeSounds.delete(sound);
}

function stopAllSounds() {
    for (const sound of activeSounds.keys()) {
        stopSound(sound);
    }
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'play' && data.sound) {
        stopSound(data.sound);

        const audio = new Audio(`../sounds/${data.sound}.ogg`);
        audio.volume = Number.isFinite(data.volume) ? data.volume : 0.65;
        audio.loop = data.loop === true;
        audio.play().catch(() => {});
        activeSounds.set(data.sound, audio);
    }

    if (data.action === 'stop' && data.sound) {
        stopSound(data.sound);
    }

    if (data.action === 'stopAll') {
        stopAllSounds();
    }
});
