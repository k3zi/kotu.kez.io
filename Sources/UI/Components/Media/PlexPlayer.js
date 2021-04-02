import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';
import dashjs from 'dashjs';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Breadcrumb from 'react-bootstrap/Breadcrumb';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import ListGroup from 'react-bootstrap/ListGroup';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Table from 'react-bootstrap/Table';

import CreateNoteForm from './../Flashcard/Modals/CreateNoteForm';
import ConfigurePlexServer from './ConfigurePlexServer';
import ServerList from './ServerList';

import UserContext from './../Context/User';

class PlexPlayer extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            playerRef: null,
            isRecording: false,
            isSubmitting: false,
            lastFile: null,
            showConfigureServer: false,
            media: [],
            useDash: false
        };
        this.playerRef = React.createRef();
    }

    componentDidMount() {
        this.setState({
            useDash: typeof(window.MediaSource || window.WebKitMediaSource) === 'function'
        });
        const self = this;
        setInterval(() => {
            self.reportPlayback();
        }, 5000);
    }

    toggleConfigureServer(show) {
        this.setState({ showConfigureServer: show });
    }

    startCapture(e) {
        e.preventDefault();
        this.setState({ isRecording: true, startTime: this.state.playerRef.currentTime });
        this.state.playerRef.play();
    }

    keyPress(e) {
        console.log(e);
        if (e.which === 32) {
            e.preventDefault();
            if (this.state.playerRef.paused) {
                this.state.playerRef.play();
            } else {
                this.state.playerRef.pause();
            }
        } else if (e.which === 39) {
            this.state.playerRef.currentTime += 10;
        } else if (e.which === 37) {
            this.state.playerRef.currentTime = max(0, this.state.playerRef.currentTime - 10);
        }
    }

    async endCapture() {
        this.state.playerRef.pause();
        this.setState({ isRecording: false, isSubmitting: true, lastFile: null });
        const startTime = this.state.startTime;
        const endTime = this.state.playerRef.currentTime;
        const response = await fetch(`${this.state.media[0].base}/capture?sessionID=${this.state.media[0].sessionID}`, {
            method: 'POST',
            body: JSON.stringify({
                startTime,
                endTime
            }),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        if (response.ok) {
            function typeInTextarea(newText) {
                const element = document.activeElement;
                const selection = window.getSelection();
                if (!selection.isCollapsed) return;

                const text = element.innerText;
                const before = text.substring(0, selection.focusOffset);
                const after  = text.substring(selection.focusOffset, text.length);
                element.innerText = before + newText + after;
                const event = new Event('change');
                element.dispatchEvent(event);
            }
            const result = await response.json();
            this.setState({ lastFile: result, isSubmitting: false });
            if (document.hasFocus() && document.activeElement.contentEditable == 'true') {
                setTimeout(() => {
                    typeInTextarea(`[audio: ${result.id}]`);
                }, 100);
            }
        } else {
            this.setState({ isSubmitting: false });
        }
    }

    async fastestURL(urls) {
        const promises = urls.map(u => fetch(u.split('/:/')[0]).then(() => u));
        return await Promise.race(promises);
    }

    async parseMedia(medias) {
        const self = this;
        const promises = medias.map(async (m) => {
            const response = await fetch(m.url);
            const urls = await response.json();
            const url = await self.fastestURL(urls);
            return {
                src: url,
                type: m.type,
                base: m.base,
                timelineURL: m.timelineURL,
                duration: m.duration,
                sessionID: m.sessionID
            };
        });
        const result = await Promise.all(promises);
        return result.filter(m => m.src);
    }

    async playMedia(medias) {
        const compatibleMedias = medias.filter(m => this.state.useDash ? (m.shortType === 'dash') : (m.shortType !== 'dash'));
        const parsedMedias = await this.parseMedia(compatibleMedias);
        if (parsedMedias.length > 0) {
            const timelineURLRequestURL = parsedMedias[0].timelineURL;
            const response = await fetch(timelineURLRequestURL);
            const urls = await response.json();
            const timelineURL = await this.fastestURL(urls);
            this.setState({ media: parsedMedias, timelineURL });
        }
        if (this.state.useDash && parsedMedias.length > 0) {
            if (this.dashPlayer) {
                this.dashPlayer.attachSource(parsedMedias[0].src);
            } else {
                this.dashPlayer = dashjs.MediaPlayer().create();
                this.dashPlayer.initialize(this.playerRef.current, parsedMedias[0].src, true);
            }
        }
    }

    canPlay(e) {
        this.setState({ playerRef: e.target });
    }

    async reportPlayback() {
        const video = this.state.playerRef;
        if (this.state.media.length === 0 || !this.state.timelineURL || !video) {
            return;
        }

        let state = 'paused';
        if (video.currentTime > 0 && !video.paused && !video.ended && video.readyState > 2) {
            state = 'playing';
        }

        const url = this.state.timelineURL + `&state=${state}&time=${Math.round(video.currentTime * 1000)}&duration=${this.state.media[0].duration}`;
        await fetch(url);
    }

    render() {
        return (
            <UserContext.Consumer>{user => (
                <Row>
                    <Col xs={12} md={7}>
                        <div className={this.state.media.length > 0 ? '' : 'd-none'}>
                            <video ref={this.playerRef} width="100%" controls autoPlay onCanPlay={(e) => this.canPlay(e)}>
                                {this.state.media.map((m, i) => (
                                    <source src={m.src} type={m.type} />
                                ))}
                            </video>
                            <hr />
                        </div>
                        {user.plexAuth && <ServerList onPlayMedia={(m) => this.playMedia(m)} user={user} />}
                        <hr />
                        <Button variant='secondary' className='mt-0 col-12' onClick={() => this.setState({ showConfigureServer: true })}>Configure Server</Button>
                    </Col>

                    <Col xs={12} md={5}>
                        <Button onTouchStart={(e) => this.startCapture(e)} onMouseDown={(e) => this.startCapture(e)} onTouchEnd={() => this.endCapture()} onMouseUp={() => this.endCapture()} className='col-12 mt-3 mt-md-0 user-select-none' variant={this.state.isRecording ? 'warning' : (this.state.isSubmitting ? 'secondary' : 'danger')} type="submit" disabled={this.state.isSubmitting || this.state.media.length === 0}>
                            {this.state.isRecording ? 'Release to Capture' : (this.state.isSubmitting ? 'Capturing' : 'Hold to Record')}
                        </Button>
                        {this.state.lastFile && <Alert dismissible onClose={() => this.setState({ lastFile: null })} className='mt-3' variant='primary'>Audio Embed Code: <pre className='mb-0 user-select-all'>[audio: {this.state.lastFile.id}]</pre></Alert>}
                        <CreateNoteForm className='mt-3' onSuccess={() => { }} />
                    </Col>
                    <ConfigurePlexServer show={this.state.showConfigureServer} onHide={() => this.toggleConfigureServer(false)} onSuccess={() => this.toggleConfigureServer(false)} />
                </Row>
            )
            }</UserContext.Consumer>);
    }
}

export default PlexPlayer;
