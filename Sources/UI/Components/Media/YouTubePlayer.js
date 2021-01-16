import React from 'react';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import YouTube from 'react-youtube';

import CreateNoteForm from './../Flashcard/Modals/CreateNoteForm';

class YouTubePlayer extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            youtubeID: '',
            youtubeVideoInfo: {},
            playerRef: null,
            isRecording: false,
            lastFile: null
        };
    }

    loadVideo(e) {
        const url = e.target.value;
        let id = url.split(/(vi\/|v=|\/v\/|youtu\.be\/|\/embed\/)/);
        id = (id[2] !== undefined) ? id[2].split(/[^0-9a-z_\-]/i)[0] : id[0];
        this.setState({ youtubeID: id, youtubeVideoInfo: {} });
    }

    videoOnReady(e) {
        const info = e.target.getVideoData();
        this.setState({
            youtubeVideoInfo: {
                author: info.author,
                videoID: info.video_id,
                title: info.title
            },
            playerRef: e.target
        });
    }

    startCapture(e) {
        e.preventDefault();
        this.setState({ isRecording: true, startTime: this.state.playerRef.getCurrentTime() });
        this.state.playerRef.playVideo();
    }

    async endCapture() {
        this.state.playerRef.pauseVideo();
        this.setState({ isRecording: false, isSubmitting: true, lastFile: null });
        const startTime = this.state.startTime;
        const endTime = this.state.playerRef.getCurrentTime();
        const response = await fetch(`/api/media/youtube/capture`, {
            method: 'POST',
            body: JSON.stringify({
                startTime,
                endTime,
                youtubeID: this.state.youtubeID
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

    render() {
        return (
            <Row>
                <Col xs={12} md={7}>
                    <Form.Control autoComplete='off' className='text-center' type="text" name="youtubeID" onChange={(e) => this.loadVideo(e)} placeholder="YouTube ID / URL" />
                    {this.state.youtubeID.length > 0 && <ResponsiveEmbed className='mt-3' aspectRatio="16by9">
                        <YouTube videoId={this.state.youtubeID} onReady={(e) => this.videoOnReady(e)} opts={{ playerVars: { modestbranding: 1, fs: 0, autoplay: 1 }}} />
                    </ResponsiveEmbed>}
                </Col>

                <Col xs={12} md={5}>
                    <Button onMouseDown={(e) => this.startCapture(e)} onMouseUp={() => this.endCapture()} className='col-12 mt-3 mt-md-0' variant={this.state.isRecording ? 'warning' : (this.state.isSubmitting ? 'secondary' : 'danger')} type="submit" disabled={this.state.isSubmitting || !this.state.youtubeID}>
                        {this.state.isRecording ? 'Release to Capture' : (this.state.isSubmitting ? 'Capturing' : 'Hold to Record')}
                    </Button>
                    {this.state.lastFile && <Alert dismissible onClose={() => this.setState({ lastFile: null })} className='mt-3' variant='primary'>Audio Embed Code: <pre className='mb-0 user-select-all'>[audio: {this.state.lastFile.id}]</pre></Alert>}
                    <CreateNoteForm className='mt-3' onSuccess={() => { }} />
                </Col>
            </Row>
        );
    }
}

export default YouTubePlayer;
