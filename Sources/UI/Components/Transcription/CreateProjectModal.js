import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import YouTube from 'react-youtube';

class CreateProjectModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            isSubmitting: false,
            didError: false,
            message: null,
            success: false,
            languages: [],
            youtubeID: '',
            youtubeVideoInfo: {}
        };
    }

    async componentDidMount() {
        const response = await fetch('/api/settings/languages');
        if (response.ok) {
            const languages = await response.json();
            this.setState({ languages });
        }
    }

    async submit(event) {
        event.preventDefault();
        if (this.success || this.isSubmitting || !this.state.youtubeVideoInfo.videoID) {
            return;
        }
        this.setState({ isSubmitting: true, didError: false, message: null });

        const data = Object.fromEntries(new FormData(event.target));
        data.youtubeID = this.state.youtubeVideoInfo.videoID;
        const response = await fetch('/api/transcription/project/create', {
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        const result = await response.json();
        const success = !result.error;
        this.setState({
            isSubmitting: false,
            didError: result.error,
            message: result.error ? result.reason : 'Loading new project...',
            success
        });

        if (success) {
            setTimeout(() => {
                location.reload();
                window.location.href = `/transcription/${result.id}`;
            }, 3000);
        }
    }

    loadVideo(e) {
        const url = e.target.value;
        let id = url.split(/(vi\/|v=|\/v\/|youtu\.be\/|\/embed\/)/);
        id = (id[2] !== undefined) ? id[2].split(/[^0-9a-z_\-]/i)[0] : id[0];
        this.setState({ youtubeID: id, youtubeVideoInfo: {} });
    }

    videoOnReady(e) {
        const info = e.target.getVideoData();
        this.setState({ youtubeVideoInfo: {
            author: info.author,
            videoID: info.video_id,
            title: info.title
        }
        });
    }

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Create Project
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <Form onSubmit={(e) => this.submit(e)}>
                        <Form.Group controlId="createProjectModalYouTubeID">
                            <Form.Label>YouTube ID / URL</Form.Label>
                            <Form.Control type="text" name="youtubeID" onChange={(e) => this.loadVideo(e)} placeholder="Enter the ID of the YouTube video" />
                        </Form.Group>

                        {this.state.youtubeID.length > 0 && <Row className='mt-3'>
                            <Col>
                                <ResponsiveEmbed aspectRatio="16by9">
                                    <YouTube videoId={this.state.youtubeID} onReady={(e) => this.videoOnReady(e)} />
                                </ResponsiveEmbed>
                            </Col>
                            <Col>
                                <strong>ID</strong>: {this.state.youtubeVideoInfo.videoID || this.state.youtubeID}
                                <br />
                                <strong>Title</strong>: {this.state.youtubeVideoInfo.title || <Badge variant="danger">Video Not Found</Badge>}
                            </Col>
                        </Row>}

                        {this.state.youtubeVideoInfo.videoID && <Form.Group controlId="createProjectModalName">
                            <Form.Label>Name</Form.Label>
                            <Form.Control type="text" name="name" defaultValue={this.state.youtubeVideoInfo.title} placeholder="Enter the name of the project" />
                        </Form.Group>}

                        {this.state.youtubeVideoInfo.videoID && <Form.Group controlId="createProjectModalLanguage">
                            <Form.Label>Original Language</Form.Label>
                            <Form.Control as="select" name="languageID" placeholder="Select content original language" >
                                {this.state.languages.map(language => {
                                    return <option key={language.id} value={language.id}>{language.name}</option>;
                                })}
                            </Form.Control>
                        </Form.Group>}

                        {this.state.didError && <Alert variant="danger">
                            {this.state.message}
                        </Alert>}
                        {!this.state.didError && this.state.message && <Alert variant="info">
                            {this.state.message}
                        </Alert>}

                        {this.state.youtubeVideoInfo.videoID && this.state.languages.length > 0 && !this.state.success && <Button className='mt-3 col-12' variant="primary" type="submit" disabled={this.state.isSubmitting}>
                            {this.state.isSubmitting ? 'Loading...' : 'Create'}
                        </Button>}
                    </Form>
                </Modal.Body>
            </Modal>
        );
    }
}

export default CreateProjectModal;
