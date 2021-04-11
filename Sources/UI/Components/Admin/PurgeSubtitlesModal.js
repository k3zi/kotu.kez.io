import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ListGroup from 'react-bootstrap/ListGroup';
import Row from 'react-bootstrap/Row';
import YouTube from 'react-youtube';

class PurgeSubtitlesModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            show: true,
            subtitles: []
        };
    }

    componentDidUpdate(prevProps) {
        if (prevProps.fetchURL != this.props.fetchURL) {
            if (this.props.fetchURL) {
                this.fetch();
            }
        }
    }

    async fetch() {
        const response = await fetch(this.props.fetchURL);
        if (response.ok) {
            const subtitles = await response.json();
            this.setState({ subtitles });
            return subtitles;
        }
        return [];
    }

    async delete(subtitle) {
        if (this.isSubmitting) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });
        const response = await fetch(`/api/admin/subtitle/${subtitle.video.id}/${subtitle.id}`, {
            method: 'DELETE'
        });

        const subtitles = await this.fetch();
        if (subtitles.length === 0) {
            this.props.onHide();
        }
    }

    playAudio(url) {
        if (this.audio) {
            this.audio.pause();
            this.audio.src = url;
        } else {
            this.audio = new Audio(url);
        }
        this.audio.play();
    }

    render() {
        return (
            <Modal {...this.props} show={!!this.props.fetchURL} size="lg" centered>
                <Modal.Header closeButton>
                    <Modal.Title>
                        {this.props.title}
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <ListGroup>
                        {this.state.subtitles.map((s, i) => {
                            return <ListGroup.Item key={i} className='text-break text-wrap d-flex align-items-center' as="button" style={{ whiteSpace: 'normal' }}>
                                <span className='cursor-pointer pe-2' onClick={() => this.playAudio(`/api/media/external/audio/${s.externalFile.id}`)}><i class='bi bi-play-circle-fill'></i></span>
                                <span className='me-auto text-start'>{s.text}</span>
                                <span className='btn btn-danger flex-shrink-0' onClick={() => this.delete(s)}>Delete</span>
                            </ListGroup.Item>;
                        })}
                    </ListGroup>
                </Modal.Body>
            </Modal>
        );
    }

}

export default PurgeSubtitlesModal;
