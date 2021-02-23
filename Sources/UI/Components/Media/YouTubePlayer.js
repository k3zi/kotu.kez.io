import React from 'react';
import { withRouter } from 'react-router';
import { LinkContainer } from 'react-router-bootstrap';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import Form from 'react-bootstrap/Form';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Table from 'react-bootstrap/Table';
import YouTube from 'react-youtube';

import CreateNoteForm from './../Flashcard/Modals/CreateNoteForm';
import Helpers from './../Helpers';

class YouTubePlayer extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            youtubeID: '',
            youtubeVideoInfo: {},
            playerRef: null,
            isRecording: false,
            lastFile: null,
            subtitles: [],
            subtitle: null,
            subtitleHTML: null,
            didDoInitialSeek: false,
            visualType: 'none',
            rubyType: 'none'
        };
    }

    componentDidMount() {
        const self = this;
        setInterval(() => {
            self.loadSubtitle();
        }, 250);

        if (this.props.match.params.id && this.props.match.params.id.length > 0) {
            this.loadVideo(this.props.match.params.id);
        }
    }

    componentDidUpdate(prevProps) {
        if (this.props.match.params.id != prevProps.match.params.id && this.props.match.params.id && this.props.match.params.id.length > 0) {
            this.loadVideo(this.props.match.params.id);
        } else if (this.props.match.params.startTime != prevProps.match.params.startTime && this.state.didDoInitialSeek) {
            this.state.playerRef.seekTo(this.props.match.params.startTime);
        }

        if (this.props.match.params.startTime && this.state.playerRef && !this.state.didDoInitialSeek) {
            this.state.playerRef.seekTo(this.props.match.params.startTime);
            this.setState({ didDoInitialSeek: true });
        }
    }

    async goToVideo(e) {
        const url = e.target.value;
        let id = url.split(/(vi\/|v=|\/v\/|youtu\.be\/|\/embed\/)/);
        id = (id[2] !== undefined) ? id[2].split(/[^0-9a-z_\-]/i)[0] : id[0];
        if (id && id.length > 0) {
            this.props.history.push(`/media/youtube/${id}`);
        } else {
            this.props.history.push(`/media/youtube`);
        }
    }

    async loadVideo(id) {
        this.setState({ youtubeID: id, youtubeVideoInfo: {}, subtitles: [], subtitle: null,  });
        const response = await fetch(`/api/media/youtube/subtitles/${id}`);
        if (response.ok) {
            const subtitles = await response.json();
            subtitles.forEach(s => {
                s.text = s.text.replace(/(\r\n|\n|\r)/gm, '');
            });
            this.setState({ subtitles });
        }
    }

    async loadSubtitle() {
        if (!this.state.playerRef) {
            return;
        }
        const time = this.state.playerRef.getCurrentTime();
        const subtitle = this.state.subtitles.find(s => s.startTime < time && time < s.endTime);
        if (this.state.subtitle != subtitle) {
            this.setState({ subtitle });
            const element = await Helpers.generateVisualSentenceElement(`<div class='page'><span>${subtitle.text}</span></div>`, subtitle.text);
            if (this.state.subtitle == subtitle) {
                this.setState({ subtitleHTML: element.innerHTML });
            }
        }
    }

    goToPreviousSub() {
        if (!this.state.playerRef) {
            return;
        }
        const time = this.state.playerRef.getCurrentTime();
        let index = this.state.subtitles.findIndex(s => s.startTime < time && time < s.endTime);
        if (index < 0) {
            index = this.state.subtitles.findIndex(s => s.startTime >= time) - 1;
        }
        index = Math.max(index - 1, 0);
        const subtitle = this.state.subtitles[index];
        this.state.playerRef.seekTo(subtitle.startTime);
    }

    goToNextSub() {
        if (!this.state.playerRef) {
            return;
        }
        const time = this.state.playerRef.getCurrentTime();
        let index = this.state.subtitles.findIndex(s => s.startTime < time && time < s.endTime);
        if (index < 0) {
            index = this.state.subtitles.findIndex(s => s.startTime >= time) - 1;
        }
        index = Math.min(index + 1, this.state.subtitles.length - 1);
        const subtitle = this.state.subtitles[index];
        this.state.playerRef.seekTo(subtitle.startTime);
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

    typeInTextarea(newText) {
        const element = document.activeElement;
        const selection = window.getSelection();
        if (!selection.isCollapsed) return;

        const text = element.innerText;
        const before = text.substring(0, selection.focusOffset);
        const after  = text.substring(selection.focusOffset, text.length);
        element.innerText = before + newText + after;
        element.dispatchEvent(new Event('change', { bubbles: true }));
        element.dispatchEvent(new Event('input', { bubbles: true }));
        setTimeout(() => {
            const textNode = document.activeElement.childNodes[0];
            const range = document.createRange();
            const end = before.length + newText.length;
            range.setStart(textNode, end);
            range.setEnd(textNode, end);
            selection.removeAllRanges();
            selection.addRange(range);
        }, 100);
    }

    async capture(startTime, endTime, e) {
        this.setState({ isSubmitting: true });
        if (e) e.preventDefault();
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
            const result = await response.json();
            this.setState({ lastFile: result, isSubmitting: false });
            if (document.hasFocus() && document.activeElement.contentEditable == 'true') {
                setTimeout(() => {
                    this.typeInTextarea(`[audio: ${result.id}]`);
                }, 100);
            }
        } else {
            this.setState({ isSubmitting: false });
        }
    }

    async copy(text, e) {
        if (e) e.preventDefault();

        if (document.hasFocus() && document.activeElement.contentEditable == 'true') {
            setTimeout(() => {
                this.typeInTextarea(text);
            }, 100);
        }
    }

    startCapture(e) {
        e.preventDefault();
        this.setState({ isRecording: true, startTime: this.state.playerRef.getCurrentTime() });
        this.state.playerRef.playVideo();
    }

    async endCapture() {
        this.state.playerRef.pauseVideo();
        this.setState({ isRecording: false, lastFile: null });
        const startTime = this.state.startTime;
        const endTime = this.state.playerRef.getCurrentTime();
        await this.capture(startTime, endTime);
    }

    frequencyOptions() {
        return [
            { name: 'Very Common', value: 'veryCommon' },
            { name: 'Common', value: 'common' },
            { name: 'Uncommon', value: 'uncommon' },
            { name: 'Rare', value: 'rare' },
            { name: 'Very Rare', value: 'veryRare' },
            { name: 'Unknown', value: 'unknown' }
        ];
    }

    visualOptions() {
        return [{ name: 'Underline Frequency', value: 'showFrequency' }, { name: 'Underline Pitch Accent', value: 'showPitchAccent' }, { name: 'Show Pitch Drops', value: 'showPitchAccentDrops' }, { name: 'None', value: 'none' }];
    }

    furiganaFrequencyOptions() {
        return [{ name: 'Hide Furigana', value: 'none' }, ...this.frequencyOptions()];
    }

    render() {
        return (
            <Row>
                <Col xs={12} md={7}>
                    <Form.Control autoComplete='off' className='text-center' type="text" name="youtubeID" onChange={(e) => this.goToVideo(e)} placeholder="YouTube ID / URL" defaultValue={this.props.match.params.id ? `https://youtu.be/${this.props.match.params.id}` : ''} />
                    {this.state.youtubeID.length > 0 && <ResponsiveEmbed className='mt-3' aspectRatio="16by9">
                        <YouTube videoId={this.state.youtubeID} onReady={(e) => this.videoOnReady(e)} opts={{ playerVars: { modestbranding: 1, fs: 0, autoplay: 1 }}} />
                    </ResponsiveEmbed>}
                    {this.state.subtitles.length > 0 && <div className='bg-dark text-white-50 py-1 px-3 d-flex justify-content-between align-items-center'>
                        <span style={{ cursor: 'pointer' }} onClick={() => this.goToPreviousSub()}><i class="bi bi-arrow-left"></i></span>
                        <span>
                            <Dropdown as='span'>
                                <Dropdown.Toggle as='span' className='pe-1'>
                                    Visual: {this.visualOptions().filter(f => f.value === this.state.visualType)[0].name}
                                </Dropdown.Toggle>

                                <Dropdown.Menu>
                                    {this.visualOptions().map((item, i) => {
                                        return <Dropdown.Item key={i} active={this.state.visualType === item.value} onSelect={(e) => this.setState({ visualType: item.value })}>{item.name}</Dropdown.Item>;
                                    })}
                                </Dropdown.Menu>
                            </Dropdown>
                            ｜
                            <Dropdown as='span'>
                                <Dropdown.Toggle as='span' className='ps-1'>
                                    Frequency: {this.furiganaFrequencyOptions().filter(f => f.value === this.state.rubyType)[0].name}
                                </Dropdown.Toggle>

                                <Dropdown.Menu>
                                    {this.furiganaFrequencyOptions().map((item, i) => {
                                        return <Dropdown.Item key={i} active={this.state.rubyType === item.value} onSelect={(e) => this.setState({ rubyType: item.value })}>{item.name}</Dropdown.Item>;
                                    })}
                                </Dropdown.Menu>
                            </Dropdown>
                        </span>
                        <span style={{ cursor: 'pointer' }} onClick={() => this.goToNextSub()}><i class="bi bi-arrow-right"></i></span>
                    </div>}
                    {this.state.subtitles.length > 0 && <div className='bg-secondary text-light text-center p-3 d-flex justify-content-between align-items-center'>
                        <Button onMouseDown={(e) => e.preventDefault()} onMouseUp={(e) => this.copy(this.state.subtitle.text, e)} onTouchEnd={(e) => this.copy(this.state.subtitle.text, e)} disabled={!this.state.subtitle} className='user-select-none mx-1'>
                            <i class="bi bi-clipboard"></i>
                        </Button>
                        {this.state.subtitleHTML && <span className={`fs-5 visual-type-${this.state.visualType} ruby-type-${this.state.rubyType} text-center`} dangerouslySetInnerHTML={{__html: this.state.subtitleHTML}}></span>}
                        <Button onMouseDown={(e) => e.preventDefault()} onMouseUp={(e) => this.capture(this.state.subtitle.startTime, this.state.subtitle.endTime, e)} onTouchEnd={(e) => this.capture(this.state.subtitle.startTime, this.state.subtitle.endTime, e)} disabled={!this.state.subtitle || this.state.isSubmitting || !this.state.youtubeID} className='user-select-none mx-1' variant='danger'>
                            <i class="bi bi-record2"></i>
                        </Button>
                    </div>}
                </Col>

                <Col xs={12} md={5}>
                    <Button onTouchStart={(e) => this.startCapture(e)} onMouseDown={(e) => this.startCapture(e)} onTouchEnd={() => this.endCapture()} onMouseUp={() => this.endCapture()} className='col-12 mt-3 mt-md-0 user-select-none' variant={this.state.isRecording ? 'warning' : (this.state.isSubmitting ? 'secondary' : 'danger')} type="submit" disabled={this.state.isSubmitting || !this.state.youtubeID}>
                        {this.state.isRecording ? 'Release to Capture' : (this.state.isSubmitting ? 'Capturing' : 'Hold to Record')}
                    </Button>
                    {this.state.lastFile && <Alert dismissible onClose={() => this.setState({ lastFile: null })} className='mt-3' variant='primary'>Audio Embed Code: <pre className='mb-0 user-select-all'>[audio: {this.state.lastFile.id}]</pre></Alert>}
                    <CreateNoteForm className='mt-3' onSuccess={() => { }} />
                </Col>
            </Row>
        );
    }
}

export default withRouter(YouTubePlayer);
