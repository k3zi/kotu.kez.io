import React from 'react';
import UserContext from './Context/User';

class KeybindObserver extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            keybind: this.emptyKeybind(),
            pressedKeys: []
        };

        this.onKeyDown = this.onKeyDown.bind(this);
        this.onKeyUp = this.onKeyUp.bind(this);
    }

    componentDidMount() {
        document.addEventListener('keydown', this.onKeyDown);
        document.addEventListener('keyup', this.onKeyUp);
    }

    componentWillUnmount() {
        document.removeEventListener('keydown', this.onKeyDown);
        document.removeEventListener('keyup', this.onKeyUp);
    }

    keybindFromEvent(e) {
        return {
            key: e.key,
            ctrlKey: e.ctrlKey,
            shiftKey: e.shiftKey,
            altKey: e.altKey,
            metaKey: e.metaKey
        };
    }

    onKeyDown(e) {
        if (e.target.matches('input') || e.target.matches('textarea') || e.target.matches('[contenteditable]')) {
            return;
        }

        this.state.pressedKeys[e.key] = true;
        const partialKeybind = this.keybindFromEvent(e);
        const keybind = this.state.keybind;
        if (!e.getModifierState(partialKeybind.key) && partialKeybind.key && !keybind.keys.includes(partialKeybind.key)) {
            keybind.keys.push(partialKeybind.key);
        }
        keybind.ctrlKey = keybind.ctrlKey || partialKeybind.ctrlKey;
        keybind.shiftKey = keybind.shiftKey || partialKeybind.shiftKey;
        keybind.altKey = keybind.altKey || partialKeybind.altKey;
        keybind.metaKey = keybind.metaKey || partialKeybind.metaKey;
        this.state.keybind = keybind;
        if (!e.repeat) {
            this.props.onKeybind && this.props.onKeybind((kb) => {
                return kb !== 'disabled'
                    && kb.keys.length === keybind.keys.length
                    && kb.keys.every(k => keybind.keys.includes(k))
                    && kb.ctrlKey === keybind.ctrlKey
                    && kb.shiftKey === keybind.shiftKey
                    && kb.altKey === keybind.altKey
                    && kb.metaKey === keybind.metaKey
            });
        }
    }

    onKeyUp(e) {
        if (e.target.matches('input') || e.target.matches('textarea') || e.target.matches('[contenteditable]')) {
            return;
        }

        this.state.pressedKeys[e.key] = false;
        // The Meta key impedes other keyup events so assume that all keys are unpressed when the meta key is.
        if (e.key.startsWith('Meta') || Object.values(this.state.pressedKeys).every(k => !k)) {
            const keybind = this.state.keybind;
            this.state.keybind = this.emptyKeybind();
            this.state.pressedKeys = [];
        }
    }

    emptyKeybind() {
        return {
            keys: [],
            ctrlKey: false,
            shiftKey: false,
            altKey: false,
            metaKey: false
        };
    }

    render() {
        return React.cloneElement(React.Children.only(this.props.children), {...this.props});
    }

}

export default KeybindObserver;
