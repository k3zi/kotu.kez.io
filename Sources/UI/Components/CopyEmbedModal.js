import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';

class CopyEmbedModal extends React.Component {

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
            <Modal {...this.props} show={!!this.props.value} size="lg" centered>
                <Modal.Header closeButton>
                    <Modal.Title>
                        Embed
                    </Modal.Title>
                </Modal.Header>

                {!this.props.value && <h1 className="text-center mt-1 mb-3"><Spinner animation="border" variant="secondary" /></h1>}
                {this.props.value && <Modal.Body>
                    <Form>
                        <Form.Group>
                            <InputGroup className="mb-3">
                                <Form.Control id="copyEmbedModalEmbed" className="hide-scrollbar" value={this.props.value} />
                                <Button variant="outline-secondary" onClick={(e) => this.onCopy(e, 'copyEmbedModalEmbed')}>Copy</Button>
                            </InputGroup>
                        </Form.Group>
                    </Form>
                </Modal.Body>}
            </Modal>
        );
    }
}

export default CopyEmbedModal;
