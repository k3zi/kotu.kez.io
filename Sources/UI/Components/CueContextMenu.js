import * as clipboard from 'clipboard-polyfill/text';
import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Dropdown from 'react-bootstrap/Dropdown';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import Spinner from 'react-bootstrap/Spinner';

class CueContextMenu extends React.Component {

    constructor(props) {
        super(props);
    }

    async copy() {
        let subtitleIndex = this.props.target.dataset.subtitleIndex;
        if (typeof subtitleIndex === 'undefined') {
            return;
        }
        subtitleIndex = parseInt(subtitleIndex);
        if (typeof subtitleIndex === undefined || subtitleIndex == null || isNaN(subtitleIndex)) {
            return;
        }
        const endSubtitleIndex = parseInt(subtitleIndex) + 1;
        const nextCue = document.querySelector(`cue[data-subtitle-index='${endSubtitleIndex}']`);
        const text = this.getTextBetween(this.props.target, nextCue);
        await clipboard.writeText(text);
        this.props.onHide();
    }

    async copyAudioEmbed() {
        const url = this.props.target.dataset.url;
        if (typeof url === 'undefined' || url.length <= 0) {
            return;
        }
        const parts = url.split('/');
        const id = parts[parts.length - 1];
        if (id.length <= 0) {
            return;
        }
        await clipboard.writeText(`[audio: ${id}]`);
        this.props.onHide();
    }

    getTextBetween(startNode, endNode) {
        let node = startNode.nextSibling;
        let text = '';
        while (node && node.nextSibling) {
            if (node.tagName.toLowerCase() === 'cue') {
                break;
            }
            text += node.innerText;
            node = node.nextSibling;
        }
        return text;
    }

    render() {
        return (
            <>
                <div className={`dropdown-menu ${this.props.target ? 'show' : ''}`} style={{ top: `${this.props.y}px`, left: `${this.props.x}px`, zIndex: 3050, position: 'fixed', width: 'auto' }}>
                    <Dropdown.Item onClick={() => this.copy()}>Copy Sentence</Dropdown.Item>
                    <Dropdown.Item onClick={() => this.copyAudioEmbed()}>Copy Audio Embed</Dropdown.Item>
                    <Dropdown.Item download as='a' href={this.props.target && this.props.target.dataset.url}>Download Audio</Dropdown.Item>
                </div>
                <div onClick={() => this.props.onHide()} style={{ height: '100vh', width: '100vw', position: 'fixed', top: 0, left: 0, zIndex: 2050, display: (this.props.target) ? 'block' : 'none' }}></div>
            </>
        );
    }

}

export default CueContextMenu;
