import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';

class FragmentEmbedModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            embed: null
        };
    }

    componentDidUpdate(prevProps) {
        if (prevProps.fragment != this.props.fragment && this.props.fragment) {
            this.load();
        }
    }

    async load() {
        this.setState({ embed: null });
        const fragment = this.props.fragment;
        const project = this.props.project;
        const response = await fetch(`/api/media/youtube/capture`, {
            method: 'POST',
            body: JSON.stringify({
                startTime: fragment.startTime,
                endTime: fragment.endTime,
                youtubeID: project.youtubeID
            }),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        if (response.ok) {
            const result = await response.json();
            this.setState({
                embed: `[audio: ${result.id}]`
            });
        }
    }

    onCopy(e, id) {
        const target = document.getElementById(id);
        target.select();
        target.setSelectionRange(0, 99999);
        document.execCommand('copy');

        e.target.innerText = 'Copied';
        setTimeout(() => {
            e.target.innerText = 'Copy';
        }, 3000);
    }

    render() {
        return (
            <Modal {...this.props} show={!!this.props.fragment} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Fragment Embed
                    </Modal.Title>
                </Modal.Header>

                {!this.state.embed && <h1 className="text-center mt-1 mb-3"><Spinner animation="border" variant="secondary" /></h1>}
                {this.state.embed && <Modal.Body>
                    <Form>
                        <Form.Group>
                            <Form.Label>Audio</Form.Label>
                            <InputGroup className="mb-3">
                                <Form.Control id="FragmentEmbedModal-embed" className="hide-scrollbar" value={this.state.embed} />
                                <Button variant="outline-secondary" onClick={(e) => this.onCopy(e, 'FragmentEmbedModal-embed')}>Copy</Button>
                            </InputGroup>
                        </Form.Group>
                    </Form>
                </Modal.Body>}
            </Modal>
        );
    }
}

export default FragmentEmbedModal;
